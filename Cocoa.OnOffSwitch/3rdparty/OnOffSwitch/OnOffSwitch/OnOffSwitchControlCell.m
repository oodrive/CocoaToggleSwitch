//
//  PRHOnOffButtonCell.m
//  PRHOnOffButton
//
//  Created by Peter Hosey on 2010-01-10.
//  Copyright 2010 Peter Hosey. All rights reserved.
//
//  Extended by Dain Kaplan on 2012-01-31.
//  Copyright 2012 Dain Kaplan. All rights reserved.
//
//  Modernized by Oodrive,
//  Copyright 2020 Oodrive. All rights reserved.

#import "OnOffSwitchControlCell.h"

#include <Carbon/Carbon.h>

// NOTE(dk): New defines for changing appearance
#define USE_COLORED_GRADIENTS true
#define SHOW_ONOFF_LABELS true

#define ONE_THIRD  (1.0 / 3.0)
#define ONE_HALF   (1.0 / 2.0)
#define TWO_THIRDS (2.0 / 3.0)

#define THUMB_WIDTH_FRACTION 0.40f
#define THUMB_CORNER_RADIUS 10.5f
#define FRAME_CORNER_RADIUS 10.5f

#define THUMB_GRADIENT_MAX_Y_WHITE 1.0f
#define THUMB_GRADIENT_MIN_Y_WHITE 0.9f
#define BACKGROUND_GRADIENT_MAX_Y_WHITE 0.5f
#define BACKGROUND_GRADIENT_MIN_Y_WHITE TWO_THIRDS
#define BACKGROUND_SHADOW_GRADIENT_WHITE 0.0f
#define BACKGROUND_SHADOW_GRADIENT_MAX_Y_ALPHA 0.35f
#define BACKGROUND_SHADOW_GRADIENT_MIN_Y_ALPHA 0.0f
#define BACKGROUND_SHADOW_GRADIENT_HEIGHT 4.0f
#define BORDER_WHITE 0.0f

#define THUMB_SHADOW_WHITE 0.0f
#define THUMB_SHADOW_ALPHA 0.5f
#define THUMB_SHADOW_BLUR 3.0f

#define DISABLED_OVERLAY_GRAY  1.0f
#define DISABLED_OVERLAY_ALPHA TWO_THIRDS

#define DOWNWARD_ANGLE_IN_DEGREES_FOR_VIEW(view) ([view isFlipped] ? 90.0f : 270.0f)

struct PRHOOBCStuffYouWouldNeedToIncludeCarbonHeadersFor {
	EventTime clickTimeout;
	HISize clickMaxDistance;
};

@interface  OnOffSwitchControlCell() 

@property (readwrite, retain) NSColor *customOnColor;
@property (readwrite, retain) NSColor *customOffColor;

- (CGFloat)centerXForThumbWithFrame:(NSRect)cellFrame;
- (void)drawText:(NSString *)text withFrame:(NSRect)textFrame;
- (void)tintBackgroundWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;
@end

// NOTE(dk): start additions

// NOTE(dk): Mostly taken from: http://cocoaheads.org/peg-narrative/basic-drawing.html
NSRect DKCenterRect(NSRect smallRect, NSRect bigRect)
{
    NSRect centerRect;
    centerRect.size = smallRect.size;
    centerRect.origin.x = bigRect.origin.x + (bigRect.size.width - smallRect.size.width) / 2.0;
    centerRect.origin.y = bigRect.origin.y + (bigRect.size.height - smallRect.size.height) / 2.0;
    return (centerRect);
}
// NOTE(dk): end additions

@implementation OnOffSwitchControlCell

@synthesize showsOnOffLabels;
@synthesize onOffSwitchControlColors;
@synthesize customOffColor;
@synthesize customOnColor;
@synthesize onSwitchLabel;
@synthesize offSwitchLabel;

+ (BOOL) prefersTrackingUntilMouseUp {
	return /*YES, YES, a thousand times*/ YES;
}

+ (NSFocusRingType) defaultFocusRingType {
	return NSFocusRingTypeNone;
}

- (void) furtherInit {
	[self setFocusRingType:[[self class] defaultFocusRingType]];
	stuff = NSZoneMalloc([self zone], sizeof(struct PRHOOBCStuffYouWouldNeedToIncludeCarbonHeadersFor));
	OSStatus err = HIMouseTrackingGetParameters(kMouseParamsSticky, &(stuff->clickTimeout), &(stuff->clickMaxDistance));
	if (err != noErr) {
		//Values returned by the above function call as of 10.6.3.
		stuff->clickTimeout = ONE_THIRD * kEventDurationSecond;
		stuff->clickMaxDistance = (HISize){ 6.0f, 6.0f };
	}
	// NOTE(dk): start additions 
	self.showsOnOffLabels = YES;
	self.onOffSwitchControlColors = OnOffSwitchControlDefaultColors;
	self.onSwitchLabel = @"I";
	self.offSwitchLabel = @"O";
	// NOTE(dk): end additions
}

- (id) initImageCell:(NSImage *)image {
	if ((self = [super initImageCell:image])) {
		[self furtherInit];
	}
	return self;
}
- (id) initTextCell:(NSString *)str {
	if ((self = [super initTextCell:str])) {
		[self furtherInit];
	}
	return self;
}
//HAX: IB (I guess?) sets our focus ring type to None for some reason. Nobody asks defaultFocusRingType unless we do it (in furtherInit).
- (id) initWithCoder:(NSCoder *)decoder {
	if ((self = [super initWithCoder:decoder])) {
		[self furtherInit];
	}
	return self;
}

- (NSRect) thumbRectInFrame:(NSRect)cellFrame {
	cellFrame.size.width -= 2.0f;
	cellFrame.size.height -= 2.0f;
	cellFrame.origin.x += 1.0f;
	cellFrame.origin.y += 1.0f;

	NSRect thumbFrame = cellFrame;
	thumbFrame.size.width = thumbFrame.size.height;

    NSControlStateValue state = [self state];
	switch (state) {
        case NSControlStateValueOff:
			//Far left. We're already there; don't do anything.
			break;
        case NSControlStateValueOn:
			//Far right.
			thumbFrame.origin.x += (cellFrame.size.width - thumbFrame.size.width);
			break;
        case NSControlStateValueMixed:
			//Middle.
			thumbFrame.origin.x = (cellFrame.size.width / 2.0f) - (thumbFrame.size.width / 2.0f);
			break;
	}

	return thumbFrame;
}

// NOTE(dk): start additions

- (void) setOnOffSwitchCustomOnColor:(NSColor *)onColor offColor:(NSColor *)offColor
{
	self.customOffColor = offColor;
	self.customOnColor = onColor;
}

// NOTE(dk): Split this out so we can call it elsewhere.
- (CGFloat)centerXForThumbWithFrame:(NSRect)cellFrame
{
	NSRect thumbFrame = [self thumbRectInFrame:cellFrame];
	if (tracking) {
		thumbFrame.origin.x += trackingPoint.x - initialTrackingPoint.x;
		
		//Clamp.
		CGFloat minOrigin = cellFrame.origin.x + 1;
		CGFloat maxOrigin = cellFrame.origin.x + (cellFrame.size.width - thumbFrame.size.width - 1);
		if (thumbFrame.origin.x < minOrigin)
			thumbFrame.origin.x = minOrigin;
		else if (thumbFrame.origin.x > maxOrigin)
			thumbFrame.origin.x = maxOrigin;
	}
	return NSMidX(thumbFrame);
}

// NOTE(dk): Center the text (as able) in the provided frame and draw it.
- (void)drawText:(NSString *)text withFrame:(NSRect)textFrame {
	CGFloat fontSize = [NSFont systemFontSizeForControlSize:9];
	//[NSFont fontWithName: @"HelveticaNeue-Bold" size:fontSize];
	NSFont *sysFont = [NSFont systemFontOfSize:fontSize];
	NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
								sysFont, NSFontAttributeName, 
								[NSColor whiteColor], NSForegroundColorAttributeName, nil];
	NSSize textSize = [text sizeWithAttributes:attributes];
	NSRect textBounds = DKCenterRect(NSMakeRect(0, 0, textSize.width, textSize.height), textFrame);
	[text drawInRect: textBounds withAttributes:attributes];
}

// Applies tints to the background to show the on/off state.
- (void)tintBackgroundWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
	
	NSGraphicsContext *context = [NSGraphicsContext currentContext];
	[context saveGraphicsState];
	[[NSBezierPath bezierPathWithRoundedRect:cellFrame xRadius:FRAME_CORNER_RADIUS yRadius:FRAME_CORNER_RADIUS] addClip];
	
	// NOTE(dk): Make everything to the left of the thumb one color, and to the right another.
	NSRect thumbFrame = [self thumbRectInFrame:cellFrame];
	CGFloat thumbCenterX = [self centerXForThumbWithFrame:cellFrame];
	NSRect leftFrame;
	NSRect rightFrame;
	CGFloat offsetWidth = thumbCenterX;
	NSDivideRect(cellFrame, &leftFrame, &rightFrame, offsetWidth - cellFrame.origin.x, NSMinXEdge);
	//NSLog(@"OffsetWidth is: %f / %f; left: %f; right: %f", offsetWidth, cellFrame.origin.x, leftFrame.size.width, rightFrame.size.width);
	
	NSColor *onStartColor;
	NSColor *onEndColor;
	NSColor *offStartColor;
	NSColor *offEndColor;
		
	switch (self.onOffSwitchControlColors) {
		case OnOffSwitchControlBlueGreyColors:
			onStartColor = onEndColor = NSColor.systemBlueColor;
			offStartColor = offEndColor = NSColor.systemGrayColor;
			break;
		case OnOffSwitchControlGreenRedColors:
			onStartColor = onEndColor = NSColor.systemGreenColor;
			offStartColor = offEndColor = NSColor.systemRedColor;
			break;
		case OnOffSwitchControlBlueRedColors:
			onStartColor = onEndColor = NSColor.systemBlueColor;
			offStartColor = offEndColor = NSColor.systemRedColor;
			break;
		case OnOffSwitchControlCustomColors:
			onStartColor = onEndColor = self.customOnColor;
			offStartColor = offEndColor = self.customOffColor;
			break;
		case OnOffSwitchControlDefaultColors:
		default:
			onStartColor = onEndColor = NSColor.controlAccentColor;
			offStartColor = offEndColor = NSColor.systemGrayColor;
	}
	
	if (onStartColor != nil && offStartColor != nil) {
		NSGradient *leftBackground = [[NSGradient alloc] initWithStartingColor:onStartColor 
																	endingColor:onEndColor];
		NSGradient *rightBackground = [[NSGradient alloc] initWithStartingColor:offStartColor 
																	 endingColor:offEndColor];
		[leftBackground drawInRect:leftFrame angle:DOWNWARD_ANGLE_IN_DEGREES_FOR_VIEW(controlView)];
		[rightBackground drawInRect:rightFrame angle:DOWNWARD_ANGLE_IN_DEGREES_FOR_VIEW(controlView)];
		[leftBackground release];
		[rightBackground release];
	}
	[context restoreGraphicsState];
	
	if (self.showsOnOffLabels) {
		// Left label
		NSRect leftSizeFrame;
		leftSizeFrame.origin.x = (tracking ? thumbCenterX-(thumbFrame.size.width/2) : thumbFrame.origin.x) - (cellFrame.size.width - thumbFrame.size.width) + 2;
		leftSizeFrame.origin.y = cellFrame.origin.y;
		leftSizeFrame.size.width = cellFrame.size.width - thumbFrame.size.width - 2;
		leftSizeFrame.size.height = cellFrame.size.height;
		[self drawText:self.onSwitchLabel withFrame:leftSizeFrame];
		
		// Right label
		NSRect rightSizeFrame = leftSizeFrame;
		rightSizeFrame.origin.x = (tracking ? thumbCenterX+(thumbFrame.size.width/2): thumbFrame.origin.x + thumbFrame.size.width) + 1;
		rightSizeFrame.origin.y = cellFrame.origin.y;
		[self drawText:self.offSwitchLabel withFrame:rightSizeFrame];
	}
}
// NOTE(dk): end additions

- (void) drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
	if (tracking)
		trackingCellFrame = cellFrame;

	NSGraphicsContext *context = [NSGraphicsContext currentContext];
    CGContextRef quartzContext = [context CGContext];
	CGContextBeginTransparencyLayer(quartzContext, /*auxInfo*/ NULL);

	//Draw the background, then the frame.
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:cellFrame xRadius:FRAME_CORNER_RADIUS yRadius:FRAME_CORNER_RADIUS];

	NSColor *startColor = [NSColor colorWithCalibratedWhite:BACKGROUND_GRADIENT_MAX_Y_WHITE alpha:1.0f];
	NSColor *endColor = [NSColor colorWithCalibratedWhite:BACKGROUND_GRADIENT_MIN_Y_WHITE alpha:1.0f];
	NSGradient *background = [[[NSGradient alloc] initWithStartingColor:startColor endingColor:endColor] autorelease];
	[background drawInBezierPath:path angle:DOWNWARD_ANGLE_IN_DEGREES_FOR_VIEW(controlView)];

	[context saveGraphicsState];
	
	[[NSBezierPath bezierPathWithRoundedRect:cellFrame xRadius:FRAME_CORNER_RADIUS yRadius:FRAME_CORNER_RADIUS] addClip];
	
	// NOTE(dk): start additions
	if (USE_COLORED_GRADIENTS && ![self allowsMixedState]) {
		[self tintBackgroundWithFrame:cellFrame inView:controlView];
	}
    
    NSBezierPath *borderPath = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(cellFrame, 0.5f, 0.5f) xRadius:FRAME_CORNER_RADIUS yRadius:FRAME_CORNER_RADIUS];

    [NSColor.separatorColor setStroke];
    [borderPath stroke];
    
	[context restoreGraphicsState];

	[self drawInteriorWithFrame:cellFrame inView:controlView];

	if (![self isEnabled]) {
        
        // Paint a half-transparent overlay over the button
        [[NSColor.windowBackgroundColor colorWithAlphaComponent:0.5f] setFill];
        [[NSColor.windowBackgroundColor colorWithAlphaComponent:0.5f] setStroke];
        [borderPath stroke];
        [borderPath fill];

	}
	CGContextEndTransparencyLayer(quartzContext);
}


- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
	//Draw the thumb.
	NSRect thumbFrame = [self thumbRectInFrame:cellFrame];
	
	NSGraphicsContext *context = [NSGraphicsContext currentContext];
	[context saveGraphicsState];

	cellFrame.size.width -= 2.0f;
	cellFrame.size.height -= 2.0f;
	cellFrame.origin.x += 1.0f;
	cellFrame.origin.y += 1.0f;

	if (tracking) {
		thumbFrame.origin.x += trackingPoint.x - initialTrackingPoint.x;

		//Clamp.
		CGFloat minOrigin = cellFrame.origin.x;
		CGFloat maxOrigin = cellFrame.origin.x + (cellFrame.size.width - thumbFrame.size.width);
		if (thumbFrame.origin.x < minOrigin)
			thumbFrame.origin.x = minOrigin;
		else if (thumbFrame.origin.x > maxOrigin)
			thumbFrame.origin.x = maxOrigin;

		trackingThumbCenterX = [self centerXForThumbWithFrame:cellFrame];
	}

	NSBezierPath *thumbPath = [NSBezierPath bezierPathWithRoundedRect:thumbFrame xRadius:thumbFrame.size.height/2 yRadius:thumbFrame.size.height/2];

	[NSColor.windowBackgroundColor setFill];
	if ([self showsFirstResponder] && ([self focusRingType] != NSFocusRingTypeNone))
		NSSetFocusRingStyle(NSFocusRingBelow);
	[thumbPath fill];
    
    NSGradient *thumbGradient = [[[NSGradient alloc] initWithStartingColor:NSColor.controlColor endingColor:[NSColor.controlColor colorWithAlphaComponent:0.2f]] autorelease];
	[thumbGradient drawInBezierPath:thumbPath angle:DOWNWARD_ANGLE_IN_DEGREES_FOR_VIEW(controlView)];

    thumbPath = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(thumbFrame, -0.5, -0.5) xRadius:THUMB_CORNER_RADIUS yRadius:THUMB_CORNER_RADIUS];
    [NSColor.separatorColor setStroke];
    [thumbPath stroke];
    
    
	[context restoreGraphicsState];

	if (tracking && (getenv("PRHOnOffButtonCellDebug") != NULL)) {
		NSBezierPath *thumbCenterLine = [NSBezierPath bezierPath];
		[thumbCenterLine moveToPoint:(NSPoint){ NSMidX(thumbFrame), thumbFrame.origin.y +thumbFrame.size.height * ONE_THIRD }];
		[thumbCenterLine lineToPoint:(NSPoint){ NSMidX(thumbFrame), thumbFrame.origin.y +thumbFrame.size.height * TWO_THIRDS }];
		[thumbCenterLine stroke];

		NSBezierPath *sectionLines = [NSBezierPath bezierPath];
		if ([self allowsMixedState]) {
			[sectionLines moveToPoint:(NSPoint){ cellFrame.origin.x + cellFrame.size.width * ONE_THIRD, NSMinY(cellFrame) }];
			[sectionLines lineToPoint:(NSPoint){ cellFrame.origin.x + cellFrame.size.width * ONE_THIRD, NSMaxY(cellFrame) }];
			[sectionLines moveToPoint:(NSPoint){ cellFrame.origin.x + cellFrame.size.width * TWO_THIRDS, NSMinY(cellFrame) }];
			[sectionLines lineToPoint:(NSPoint){ cellFrame.origin.x + cellFrame.size.width * TWO_THIRDS, NSMaxY(cellFrame) }];
		} else {
			[sectionLines moveToPoint:(NSPoint){ cellFrame.origin.x + cellFrame.size.width * ONE_HALF, NSMinY(cellFrame) }];
			[sectionLines lineToPoint:(NSPoint){ cellFrame.origin.x + cellFrame.size.width * ONE_HALF, NSMaxY(cellFrame) }];
		}
		[sectionLines stroke];
	}
}

- (NSCellHitResult)hitTestForEvent:(NSEvent *)event inRect:(NSRect)cellFrame ofView:(NSView *)controlView {
	NSPoint mouseLocation = [controlView convertPoint:[event locationInWindow] fromView:nil];
	return NSPointInRect(mouseLocation, cellFrame) ? (NSCellHitContentArea | NSCellHitTrackableArea) : NSCellHitNone;
}

- (BOOL) startTrackingAt:(NSPoint)startPoint inView:(NSView *)controlView {
	//We rely on NSControl behavior, so only start tracking if this is a control.
	tracking = YES;
	trackingPoint = initialTrackingPoint = startPoint;
	trackingTime = initialTrackingTime = [NSDate timeIntervalSinceReferenceDate];
	return [controlView isKindOfClass:[NSControl class]];
}
- (BOOL) continueTracking:(NSPoint)lastPoint at:(NSPoint)currentPoint inView:(NSView *)controlView {
	NSControl *control = [controlView isKindOfClass:[NSControl class]] ? (NSControl *)controlView : nil;
	if (control) {
		trackingPoint = currentPoint;
		//No need to update the time here as long as nothing cares about it.
		trackingTime = initialTrackingTime = [NSDate timeIntervalSinceReferenceDate];
		[control drawCell:self];
		return YES;
	}
	tracking = NO;
	return NO;
}
- (void)stopTracking:(NSPoint)lastPoint at:(NSPoint)stopPoint inView:(NSView *)controlView mouseIsUp:(BOOL)flag {
	tracking = NO;
	trackingTime = [NSDate timeIntervalSinceReferenceDate];

	NSControl *control = [controlView isKindOfClass:[NSControl class]] ? (NSControl *)controlView : nil;
	if (control) {
		CGFloat xFraction = trackingThumbCenterX / trackingCellFrame.size.width;

		BOOL isClickNotDragByTime = (trackingTime - initialTrackingTime) < stuff->clickTimeout;
		BOOL isClickNotDragBySpaceX = (stopPoint.x - initialTrackingPoint.x) < stuff->clickMaxDistance.width;
		BOOL isClickNotDragBySpaceY = (stopPoint.y - initialTrackingPoint.y) < stuff->clickMaxDistance.height;
		BOOL isClickNotDrag = isClickNotDragByTime && isClickNotDragBySpaceX && isClickNotDragBySpaceY;

		if (!isClickNotDrag) {
            NSControlStateValue desiredState;

			if ([self allowsMixedState]) {
				if (xFraction < ONE_THIRD)
                    desiredState = NSControlStateValueOff;
				else if (xFraction >= TWO_THIRDS)
                    desiredState = NSControlStateValueOn;
				else
                    desiredState = NSControlStateValueMixed;
			} else {
				if (xFraction < ONE_HALF)
                    desiredState = NSControlStateValueOff;
				else
                    desiredState = NSControlStateValueOn;
			}

			//We actually need to set the state to the one *before* the one we want, because NSCell will advance it. I'm not sure how to thwart that without breaking -setNextState, which breaks AXPress and the space bar.
            NSControlStateValue stateBeforeDesiredState = NSControlStateValueOff;
			switch (desiredState) {
                case NSControlStateValueOn:
					if ([self allowsMixedState]) {
                        stateBeforeDesiredState = NSControlStateValueMixed;
						break;
					}
					//Fall through.
                case NSControlStateValueMixed:
                    stateBeforeDesiredState = NSControlStateValueOff;
					break;
                case NSControlStateValueOff:
                    stateBeforeDesiredState = NSControlStateValueOn;
					break;
					
			}

			[self setState:stateBeforeDesiredState];
		}
	}
}

@end
