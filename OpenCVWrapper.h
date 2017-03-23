//
//  OpenCVWrapper.h
//  TestOpenCVSwift
//
//  Created by Patrick Pan on 11/14/16.
//  Copyright © 2016 OpenCV Moments. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>


@interface OpenCVWrapper : NSObject

+(NSString *) openCVVersionString;

+ (UIImage *) findTemplatev2:(NSArray*)imageArray distanceFromTarget:(double)distance calculatedVelocity:(double *)velocity;

+(UIImage *) findTemplate:(UIImage *)image templateImage:(UIImage *)temp distanceFromTarget:(double)distance calculatedVelocity:(double *)velocity;

@end
