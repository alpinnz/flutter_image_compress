//
//  SYMetadata.h
//

#import <Foundation/Foundation.h>
#import <Photos/Photos.h> // Using Photos framework

#import "SYMetadataTIFF.h"
#import "SYMetadataGIF.h"
#import "SYMetadataJFIF.h"
#import "SYMetadataExif.h"
#import "SYMetadataPNG.h"
#import "SYMetadataIPTC.h"
#import "SYMetadataGPS.h"
#import "SYMetadataRaw.h"
#import "SYMetadataCIFF.h"
#import "SYMetadataMakerCanon.h"
#import "SYMetadataMakerNikon.h"
#import "SYMetadataMakerMinolta.h"
#import "SYMetadataMakerFuji.h"
#import "SYMetadataMakerOlympus.h"
#import "SYMetadataMakerPentax.h"
#import "SYMetadata8BIM.h"
#import "SYMetadataDNG.h"
#import "SYMetadataExifAux.h"

@interface SYMetadata : SYMetadataBase

@property SYMETADATA_PROPERTY_COPY NSDictionary *originalDictionary;

@property SYMETADATA_PROPERTY_STRONG SYMetadataTIFF          *metadataTIFF;
@property SYMETADATA_PROPERTY_STRONG SYMetadataExif          *metadataExif;
@property SYMETADATA_PROPERTY_STRONG SYMetadataGIF           *metadataGIF;
@property SYMETADATA_PROPERTY_STRONG SYMetadataJFIF          *metadataJFIF;
@property SYMETADATA_PROPERTY_STRONG SYMetadataPNG           *metadataPNG;
@property SYMETADATA_PROPERTY_STRONG SYMetadataIPTC          *metadataIPTC;
@property SYMETADATA_PROPERTY_STRONG SYMetadataGPS           *metadataGPS;
@property SYMETADATA_PROPERTY_STRONG SYMetadataRaw           *metadataRaw;
@property SYMETADATA_PROPERTY_STRONG SYMetadataCIFF          *metadataCIFF;
@property SYMETADATA_PROPERTY_STRONG SYMetadataMakerCanon    *metadataMakerCanon;
@property SYMETADATA_PROPERTY_STRONG SYMetadataMakerNikon    *metadataMakerNikon;
@property SYMETADATA_PROPERTY_STRONG SYMetadataMakerMinolta  *metadataMakerMinolta;
@property SYMETADATA_PROPERTY_STRONG SYMetadataMakerFuji     *metadataMakerFuji;
@property SYMETADATA_PROPERTY_STRONG SYMetadataMakerOlympus  *metadataMakerOlympus;
@property SYMETADATA_PROPERTY_STRONG SYMetadataMakerPentax   *metadataMakerPentax;
@property SYMETADATA_PROPERTY_STRONG SYMetadata8BIM          *metadata8BIM;
@property SYMETADATA_PROPERTY_STRONG SYMetadataDNG           *metadataDNG;
@property SYMETADATA_PROPERTY_STRONG SYMetadataExifAux       *metadataExifAux;

// Fallback
@property SYMETADATA_PROPERTY_COPY NSDictionary   *metadataApple;
@property SYMETADATA_PROPERTY_COPY NSDictionary   *metadataPictureStyle;

@property (nonatomic, copy, readonly)   NSNumber  *fileSize;
@property (nonatomic, copy, readonly)   NSNumber  *pixelHeight;
@property (nonatomic, copy, readonly)   NSNumber  *pixelWidth;
@property (nonatomic, copy, readonly)   NSNumber  *dpiHeight;
@property (nonatomic, copy, readonly)   NSNumber  *dpiWidth;
@property (nonatomic, copy, readonly)   NSNumber  *depth;
@property SYMETADATA_PROPERTY_COPY      NSNumber  *orientation;
@property (nonatomic, copy, readonly)   NSNumber  *isFloat;
@property (nonatomic, copy, readonly)   NSNumber  *isIndexed;
@property (nonatomic, copy, readonly)   NSNumber  *hasAlpha;
@property (nonatomic, copy, readonly)   NSString  *colorModel;
@property (nonatomic, copy, readonly)   NSString  *profileName;

+ (instancetype)metadataWithDictionary:(NSDictionary *)dictionary;
+ (instancetype)metadataWithPHAsset:(PHAsset *)asset; // Using ALAsset
+ (instancetype)metadataWithFileURL:(NSURL *)fileURL;
+ (instancetype)metadataWithImageData:(NSData *)imageData;

+ (NSDictionary *)dictionaryWithPHAsset:(PHAsset *)asset; // Using ALAssetsLibrary

+ (NSData *)dataWithImageData:(NSData *)imageData andMetadata:(SYMetadata *)metadata;

- (NSDictionary *)differencesFromOriginalMetadataToModel;

@end
