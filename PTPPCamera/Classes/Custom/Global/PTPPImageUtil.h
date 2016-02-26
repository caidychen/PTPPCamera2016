//
//  PTPPImageUtil.h
//  PTPPCamera
//
//  Created by CHEN KAIDI on 26/2/2016.
//  Copyright © 2016 Putao. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AssetHelper.h"

@interface PTPPImageUtil : NSObject
+ (UIImage *)croppIngimageByImageName:(UIImage *)imageToCrop toRect:(CGRect)rect;
+ (CGFloat) pointPairToBearingDegrees:(CGPoint)startingPoint secondPoint:(CGPoint) endingPoint;
+ (CGFloat)getDistanceFromPointA:(CGPoint)pointA pointB:(CGPoint)pointB;
+ (NSDictionary *)getFilterResultFromInputImage:(UIImage *)inputImage filterIndex:(NSInteger)index;
+ (UIImage *)getThumbnailFromALAsset:(ALAsset *)asset;
+ (UIImage *)getOriginalImageFromALAsset:(ALAsset *)asset;

+ (BOOL)checkCameraCanUse;
@end
