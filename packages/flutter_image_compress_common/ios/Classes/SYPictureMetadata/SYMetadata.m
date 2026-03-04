//
//  SYMetadata.m
//  SYPictureMetadataExample
//
//  Created by Stan Chevallier on 12/13/12.
//  Updated by Alfin (2025) – Migrated to PHAsset / Photos framework
//

#import <ImageIO/ImageIO.h>
#import "SYMetadata.h"
#import "NSDictionary+SY.h"
#import <Photos/Photos.h>

#define SYKeyForMetadata(name)          NSStringFromSelector(@selector(metadata##name))
#define SYDictionaryForMetadata(name)   SYPaste(SYPaste(kCGImageProperty,name),Dictionary)
#define SYClassForMetadata(name)        SYPaste(SYMetadata,name)
#define SYMappingPptyToClass(name)      SYKeyForMetadata(name):SYClassForMetadata(name).class
#define SYMappingPptyToKeyPath(name)    SYKeyForMetadata(name):(__bridge NSString *)SYDictionaryForMetadata(name)

@interface SYMetadata (Private)
- (void)refresh:(BOOL)force;
@end

@implementation SYMetadata

#pragma mark - Initialization

+ (instancetype)metadataWithDictionary:(NSDictionary *)dictionary
{
    if (!dictionary)
        return nil;

    NSError *error;

    SYMetadata *instance = [MTLJSONAdapter modelOfClass:self.class fromJSONDictionary:dictionary error:&error];

    if (instance)
        instance->_originalDictionary = dictionary;

    if (error)
        NSLog(@"--> Error creating %@ object: %@", NSStringFromClass(self.class), error);

    return instance;
}

/// Shared helper: synchronously fetch image data for a PHAsset and extract its metadata dictionary.
///
/// Notes:
/// - Enables iCloud downloads (networkAccessAllowed).
/// - Avoids calling Photos synchronous requests on the main thread to prevent UI jank/deadlocks.
static NSDictionary *_Nullable SYMetadataCopyImagePropertiesFromPHAsset(PHAsset *asset) {
    if (!asset) return nil;

    // Enforce off-main-thread usage to avoid blocking the UI.
    // This helper is synchronous by design; doing any kind of wait on the main thread can freeze the UI.
    if ([NSThread isMainThread]) {
        NSLog(@"[SYMetadata] SYMetadataCopyImagePropertiesFromPHAsset must not be called on the main thread; returning nil to avoid UI jank.");
        return nil;
    }

    PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
    options.version = PHImageRequestOptionsVersionCurrent;
    options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
    options.networkAccessAllowed = YES;

    __block NSData *imageData = nil;

    // Request image data. If options.synchronous == YES, Photos will invoke the handler before returning.
    void (^requestBlock)(void (^completion)(NSData *_Nullable data)) = ^(void (^completion)(NSData *_Nullable data)) {
        if (@available(iOS 13, *)) {
            [[PHImageManager defaultManager] requestImageDataAndOrientationForAsset:asset
                                                                            options:options
                                                                      resultHandler:^(NSData * _Nullable data,
                                                                                      NSString * _Nullable dataUTI,
                                                                                      CGImagePropertyOrientation orientation,
                                                                                      NSDictionary * _Nullable info) {
                completion(data);
            }];
        } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            [[PHImageManager defaultManager] requestImageDataForAsset:asset
                                                               options:options
                                                         resultHandler:^(NSData * _Nullable data,
                                                                         NSString * _Nullable dataUTI,
                                                                         UIImageOrientation orientation,
                                                                         NSDictionary * _Nullable info) {
                completion(data);
            }];
#pragma clang diagnostic pop
        }
    };

    // Off-main-thread: request synchronously to keep existing sync contract.
    options.synchronous = YES;

    // Even with synchronous=YES, Photos may still deliver via callbacks; guard with a bounded wait.
    // This also protects against iCloud/network stalls.
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    requestBlock(^(NSData *_Nullable data) {
        imageData = data;
        dispatch_semaphore_signal(sema);
    });

    long waitResult = dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC)));
    if (waitResult != 0) {
        NSLog(@"[SYMetadata] Timed out waiting for PHAsset image data (30s); returning nil.");
        return nil;
    }

    if (!imageData.length) return nil;

    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)imageData, NULL);
    if (!source) return nil;

    NSDictionary *metadataDict = (__bridge_transfer NSDictionary *)
        CGImageSourceCopyPropertiesAtIndex(source, 0, NULL);
    CFRelease(source);

    return metadataDict;
}

+ (instancetype)metadataWithPHAsset:(PHAsset *)asset
{
    NSDictionary *metadataDict = SYMetadataCopyImagePropertiesFromPHAsset(asset);
    return metadataDict ? [SYMetadata metadataWithDictionary:metadataDict] : nil;
}

+ (instancetype)metadataWithAsset:(id)asset
{
    // Best-effort source-compat wrapper: if caller already provides a PHAsset, forward to it.
    if ([asset isKindOfClass:[PHAsset class]]) {
        return [self metadataWithPHAsset:(PHAsset *)asset];
    }
    return nil;
}

+ (instancetype)metadataWithAssetURL:(NSURL *)assetURL
{
    if (!assetURL) return nil;

    PHFetchResult<PHAsset *> *fetch = [PHAsset fetchAssetsWithALAssetURLs:@[assetURL] options:nil];
    PHAsset *asset = fetch.firstObject;
    return asset ? [self metadataWithPHAsset:asset] : nil;
}

+ (instancetype)metadataWithFileURL:(NSURL *)fileURL
{
    if (!fileURL)
        return nil;

    CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)fileURL, NULL);
    if (source == NULL)
        return nil;

    NSDictionary *dictionary;

    NSDictionary *options = @{(NSString *)kCGImageSourceShouldCache:@(NO)};
    CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(source, 0, (__bridge CFDictionaryRef)options);
    if (properties) {
        dictionary = (__bridge NSDictionary*)properties;
        CFRelease(properties);
    }

    CFRelease(source);

    return [self metadataWithDictionary:dictionary];
}

+ (instancetype)metadataWithImageData:(NSData *)imageData
{
    if (!imageData.length)
        return nil;

    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef) imageData, NULL);
    if (source == NULL)
        return nil;

    NSDictionary *dictionary;

    NSDictionary *options = @{(NSString *)kCGImageSourceShouldCache:@(NO)};
    CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(source, 0, (__bridge CFDictionaryRef)options);
    if (properties) {
        dictionary = (__bridge NSDictionary*)properties;
        CFRelease(properties);
    }

    CFRelease(source);

    return [self metadataWithDictionary:dictionary];
}

#pragma mark - Writing

// https://github.com/Nikita2k/SimpleExif/blob/master/Classes/ios/UIImage%2BExif.m
+ (NSData *)dataWithImageData:(NSData *)imageData andMetadata:(SYMetadata *)metadata
{
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef) imageData, NULL);
    if (!source) {
        NSLog(@"Error: Could not create image source");
        return nil;
    }

    CFStringRef sourceImageType = CGImageSourceGetType(source);

    // create a new data object and write the new image into it
    NSMutableData *data = [NSMutableData data];
    CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)data, sourceImageType, 1, NULL);

    if (!destination) {
        NSLog(@"Error: Could not create image destination");
        CFRelease(source);
        return nil;
    }

    // add the image contained in the image source to the destination, overriding the old metadata with our modified metadata
    CGImageDestinationAddImageFromSource(destination, source, 0, (__bridge CFDictionaryRef)metadata.generatedDictionary);
    BOOL success = CGImageDestinationFinalize(destination);

    if (!success)
        NSLog(@"Error: Could not create data from image destination");

    CFRelease(destination);
    CFRelease(source);

    return (success ? data : nil);
}

#pragma mark - Getting metadata

+ (NSDictionary *)dictionaryWithPHAsset:(PHAsset *)asset
{
    return SYMetadataCopyImagePropertiesFromPHAsset(asset);
}

+ (NSDictionary *)dictionaryWithAssetURL:(NSURL *)assetURL
{
    if (!assetURL) return nil;
    PHFetchResult<PHAsset *> *fetch = [PHAsset fetchAssetsWithALAssetURLs:@[assetURL] options:nil];
    PHAsset *asset = fetch.firstObject;
    return asset ? [self dictionaryWithPHAsset:asset] : nil;
}

#pragma mark - Mapping

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    NSMutableDictionary <NSString *, NSString *> *mappings = [NSMutableDictionary dictionary];
    [mappings
     addEntriesFromDictionary:@{SYMappingPptyToKeyPath(TIFF),
                                SYMappingPptyToKeyPath(Exif),
                                SYMappingPptyToKeyPath(GIF),
                                SYMappingPptyToKeyPath(JFIF),
                                SYMappingPptyToKeyPath(PNG),
                                SYMappingPptyToKeyPath(IPTC),
                                SYMappingPptyToKeyPath(GPS),
                                SYMappingPptyToKeyPath(Raw),
                                SYMappingPptyToKeyPath(CIFF),
                                SYMappingPptyToKeyPath(MakerCanon),
                                SYMappingPptyToKeyPath(MakerNikon),
                                SYMappingPptyToKeyPath(MakerMinolta),
                                SYMappingPptyToKeyPath(MakerFuji),
                                SYMappingPptyToKeyPath(MakerOlympus),
                                SYMappingPptyToKeyPath(MakerPentax),
                                SYMappingPptyToKeyPath(8BIM),
                                SYMappingPptyToKeyPath(DNG),
                                SYMappingPptyToKeyPath(ExifAux),
                                }];
    
    [mappings
     addEntriesFromDictionary:@{SYStringSel(fileSize):      (NSString *)kCGImagePropertyFileSize,
                                SYStringSel(pixelHeight):   (NSString *)kCGImagePropertyPixelHeight,
                                SYStringSel(pixelWidth):    (NSString *)kCGImagePropertyPixelWidth,
                                SYStringSel(dpiHeight):     (NSString *)kCGImagePropertyDPIHeight,
                                SYStringSel(dpiWidth):      (NSString *)kCGImagePropertyDPIWidth,
                                SYStringSel(depth):         (NSString *)kCGImagePropertyDepth,
                                SYStringSel(orientation):   (NSString *)kCGImagePropertyOrientation,
                                SYStringSel(isFloat):       (NSString *)kCGImagePropertyIsFloat,
                                SYStringSel(isIndexed):     (NSString *)kCGImagePropertyIsIndexed,
                                SYStringSel(hasAlpha):      (NSString *)kCGImagePropertyHasAlpha,
                                SYStringSel(colorModel):    (NSString *)kCGImagePropertyColorModel,
                                SYStringSel(profileName):   (NSString *)kCGImagePropertyProfileName,
                                
                                SYStringSel(metadataApple):         (NSString *)kCGImagePropertyMakerAppleDictionary,
                                SYStringSel(metadataPictureStyle):  (NSString *)kSYImagePropertyPictureStyle,
                                }];
    
    return [mappings copy];
}

+ (NSValueTransformer *)JSONTransformerForKey:(NSString *)key
{
    static dispatch_once_t onceToken;
    static NSDictionary <NSString *, Class> *classMappings;
    dispatch_once(&onceToken, ^{
        classMappings = @{SYMappingPptyToClass(TIFF),
                          SYMappingPptyToClass(Exif),
                          SYMappingPptyToClass(GIF),
                          SYMappingPptyToClass(JFIF),
                          SYMappingPptyToClass(PNG),
                          SYMappingPptyToClass(IPTC),
                          SYMappingPptyToClass(GPS),
                          SYMappingPptyToClass(Raw),
                          SYMappingPptyToClass(CIFF),
                          SYMappingPptyToClass(MakerCanon),
                          SYMappingPptyToClass(MakerNikon),
                          SYMappingPptyToClass(MakerMinolta),
                          SYMappingPptyToClass(MakerFuji),
                          SYMappingPptyToClass(MakerOlympus),
                          SYMappingPptyToClass(MakerPentax),
                          SYMappingPptyToClass(8BIM),
                          SYMappingPptyToClass(DNG),
                          SYMappingPptyToClass(ExifAux),
                          };
    });
    
    
    Class objectClass = classMappings[key];
    
    if (objectClass)
        return [NSValueTransformer sy_dictionaryTransformerForModelOfClass:objectClass];
    
    return [super JSONTransformerForKey:key];
}

#pragma mark - Tests

- (NSDictionary *)differencesFromOriginalMetadataToModel
{
    return [NSDictionary sy_differencesFrom:self.originalDictionary
                                         to:[self generatedDictionary]
                        includeValuesInDiff:YES];
}

@end
