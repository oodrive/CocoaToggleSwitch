//
//  PRHOnOffButtonCell.h
//  PRHOnOffButton
//
//  Created by Peter Hosey on 2010-01-10.
//  Copyright 2010 Peter Hosey. All rights reserved.
//
//  Extended by Dain Kaplan on 2012-01-31.
//  Copyright 2012 Dain Kaplan. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef enum {
	OnOffSwitchControlDefaultColors = 0,
	OnOffSwitchControlCustomColors = 1,
	OnOffSwitchControlBlueGreyColors = 2,
	OnOffSwitchControlGreenRedColors = 3,
	OnOffSwitchControlBlueRedColors = 4
} OnOffSwitchControlColors;

NSRect DKCenterRect(NSRect smallRect, NSRect bigRect);

@interface OnOffSwitchControlCell : NSButtonCell {
	BOOL tracking;
	NSPoint initialTrackingPoint, trackingPoint;
	NSTimeInterval initialTrackingTime, trackingTime;
	NSRect trackingCellFrame; //Set by drawWithFrame: when tracking is true.
	CGFloat trackingThumbCenterX; //Set by drawWithFrame: when tracking is true.
	struct PRHOOBCStuffYouWouldNeedToIncludeCarbonHeadersFor *stuff;
	BOOL showsOnOffLabels;
	OnOffSwitchControlColors onOffSwitchControlColors;
	NSColor *customOnColor;
	NSColor *customOffColor;
	NSString *onSwitchLabel;
	NSString *offSwitchLabel;
}

@property (readwrite, copy) NSString *onSwitchLabel;
@property (readwrite, copy) NSString *offSwitchLabel;
@property (readwrite, assign) BOOL showsOnOffLabels;
@property (readwrite, assign) OnOffSwitchControlColors onOffSwitchControlColors;

- (void) setOnOffSwitchCustomOnColor:(NSColor *)onColor offColor:(NSColor *)offColor;

@end

// Converts NSBezierPath to CGPathRefs.
@implementation NSBezierPath (BezierPathQuartzUtilities)
// This method works only in OS X v10.2 and later.
- (CGPathRef)quartzPath
{
    int i, numElements;

    // Need to begin a path here.
    CGPathRef           immutablePath = NULL;

    // Then draw the path elements.
    numElements = [self elementCount];
    if (numElements > 0)
    {
        CGMutablePathRef    path = CGPathCreateMutable();
        NSPoint             points[3];
        BOOL                didClosePath = YES;

        for (i = 0; i < numElements; i++)
        {
            switch ([self elementAtIndex:i associatedPoints:points])
            {
                case NSMoveToBezierPathElement:
                    CGPathMoveToPoint(path, NULL, points[0].x, points[0].y);
                    break;

                case NSLineToBezierPathElement:
                    CGPathAddLineToPoint(path, NULL, points[0].x, points[0].y);
                    didClosePath = NO;
                    break;

                case NSCurveToBezierPathElement:
                    CGPathAddCurveToPoint(path, NULL, points[0].x, points[0].y,
                                        points[1].x, points[1].y,
                                        points[2].x, points[2].y);
                    didClosePath = NO;
                    break;

                case NSClosePathBezierPathElement:
                    CGPathCloseSubpath(path);
                    didClosePath = YES;
                    break;
            }
        }

        // Be sure the path is closed or Quartz may not do valid hit detection.
        if (!didClosePath)
            CGPathCloseSubpath(path);

        immutablePath = CGPathCreateCopy(path);
        CGPathRelease(path);
    }

    return immutablePath;
}
@end
