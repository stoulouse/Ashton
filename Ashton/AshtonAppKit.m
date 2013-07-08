#import "AshtonAppKit.h"
#import "AshtonIntermediate.h"
#import "AshtonUtils.h"
#import <AppKit/AppKit.h>

@implementation AshtonAppKit

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static AshtonAppKit *sharedInstance;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[AshtonAppKit alloc] init];
    });
    return sharedInstance;
}

- (NSAttributedString *)intermediateRepresentationWithTargetRepresentation:(NSAttributedString *)input {
    NSMutableAttributedString *output = [input mutableCopy];
    NSRange totalRange = NSMakeRange (0, input.length);
    [input enumerateAttributesInRange:totalRange options:0 usingBlock:^(NSDictionary *attrs, NSRange range, BOOL *stop) {
        NSMutableDictionary *newAttrs = [NSMutableDictionary dictionaryWithCapacity:[attrs count]];
        for (NSString *attrName in attrs) {
            id attr = [attrs objectForKey:attrName];
            if ([attrName isEqual:NSParagraphStyleAttributeName]) {
                // produces: paragraph
                if (![attr isKindOfClass:[NSParagraphStyle class]]) continue;
                NSParagraphStyle *paragraphStyle = (NSParagraphStyle *)attr;
                NSMutableDictionary *attrDict = [NSMutableDictionary dictionary];

                if ([paragraphStyle alignment] == NSLeftTextAlignment) [attrDict setObject:@"left" forKey:AshtonParagraphAttrTextAlignment];
                if ([paragraphStyle alignment] == NSRightTextAlignment) [attrDict setObject:@"right" forKey:AshtonParagraphAttrTextAlignment];
                if ([paragraphStyle alignment] == NSCenterTextAlignment) [attrDict setObject:@"center" forKey:AshtonParagraphAttrTextAlignment];
                if ([paragraphStyle alignment] == NSJustifiedTextAlignment) [attrDict setObject:@"justified" forKey:AshtonParagraphAttrTextAlignment];

                [newAttrs setObject:attrDict forKey:AshtonAttrParagraph];
            }
            if ([attrName isEqual:NSFontAttributeName]) {
                // produces: font
                if (![attr isKindOfClass:[NSFont class]]) continue;
                NSFont *font = (NSFont *)attr;
                NSMutableDictionary *attrDict = [NSMutableDictionary dictionary];
                NSFontDescriptor *fontDescriptor = [font fontDescriptor];
                NSFontSymbolicTraits symbolicTraits = [fontDescriptor symbolicTraits];
                if ((symbolicTraits & NSFontBoldTrait) == NSFontBoldTrait) [attrDict setObject:@(YES) forKey:AshtonFontAttrTraitBold];
                if ((symbolicTraits & NSFontItalicTrait) == NSFontItalicTrait) [attrDict setObject:@(YES) forKey:AshtonFontAttrTraitItalic];

                // non-default font feature settings
                NSArray *fontFeatures = [fontDescriptor objectForKey:NSFontFeatureSettingsAttribute];
                NSMutableSet *features = [NSMutableSet set];
                if (fontFeatures) {
                    for (NSDictionary *feature in fontFeatures) {
                        [features addObject:@[ [feature objectForKey:NSFontFeatureTypeIdentifierKey], [feature objectForKey:NSFontFeatureSelectorIdentifierKey]]];
                    }
                }

                [attrDict setObject:features forKey: AshtonFontAttrFeatures];
                [attrDict setObject:@(font.pointSize) forKey:AshtonFontAttrPointSize];
                [attrDict setObject:font.familyName forKey:AshtonFontAttrFamilyName];
                [attrDict setObject:font.fontName forKey:AshtonFontAttrPostScriptName];
                [newAttrs setObject:attrDict forKey:AshtonAttrFont];
            }
            if ([attrName isEqual:NSSuperscriptAttributeName]) {
                if (![attr isKindOfClass:[NSNumber class]]) continue;
                [newAttrs setObject:@([attr integerValue]) forKey:AshtonAttrVerticalAlign];
            }
            if ([attrName isEqual:NSBaselineOffsetAttributeName]) {
                [newAttrs setObject:@([attr floatValue]) forKey:AshtonAttrBaselineOffset];
            }
            if ([attrName isEqual:NSUnderlineStyleAttributeName]) {
                // produces: underline
                if (![attr isKindOfClass:[NSNumber class]]) continue;
                if ([attr isEqual:@(NSUnderlineStyleSingle)]) [newAttrs setObject:AshtonUnderlineStyleSingle forKey:AshtonAttrUnderline];
                if ([attr isEqual:@(NSUnderlineStyleThick)]) [newAttrs setObject:AshtonUnderlineStyleThick forKey:AshtonAttrUnderline];
                if ([attr isEqual:@(NSUnderlineStyleDouble)]) [newAttrs setObject:AshtonUnderlineStyleDouble forKey:AshtonAttrUnderline];
            }
            if ([attrName isEqual:NSUnderlineColorAttributeName]) {
                // produces: underlineColor
                if (![attr isKindOfClass:[NSColor class]]) continue;
                [newAttrs setObject:[self arrayForColor:attr] forKey:AshtonAttrUnderlineColor];
            }
            if ([attrName isEqual:NSForegroundColorAttributeName] || [attrName isEqual:NSStrokeColorAttributeName]) {
                // produces: color
                if (![attr isKindOfClass:[NSColor class]]) continue;
                [newAttrs setObject:[self arrayForColor:attr] forKey:AshtonAttrColor];
            }

            if ([attrName isEqual:NSStrikethroughStyleAttributeName]) {
                // produces: strikethrough
                if (![attr isKindOfClass:[NSNumber class]]) continue;
                if ([attr isEqual:@(NSUnderlineStyleSingle)]) [newAttrs setObject:AshtonStrikethroughStyleSingle forKey:AshtonAttrStrikethrough];
                if ([attr isEqual:@(NSUnderlineStyleThick)]) [newAttrs setObject:AshtonStrikethroughStyleThick forKey:AshtonAttrStrikethrough];
                if ([attr isEqual:@(NSUnderlineStyleDouble)]) [newAttrs	 setObject:AshtonStrikethroughStyleDouble forKey:AshtonAttrStrikethrough];
            }
            if ([attrName isEqual:NSStrikethroughColorAttributeName]) {
                // produces: strikethroughColor
                if (![attr isKindOfClass:[NSColor class]]) continue;
                [newAttrs setObject:[self arrayForColor:attr] forKey:AshtonAttrStrikethroughColor];
            }
            if ([attrName isEqual:NSLinkAttributeName]) {
				if ([attr isKindOfClass:[NSURL class]]) {
					[newAttrs setObject:[attr absoluteString] forKey:AshtonAttrLink];
				} else if ([attr isKindOfClass:[NSString class]]) {
					[newAttrs setObject:attr forKey:AshtonAttrLink];
				}
            }
        }
        [output setAttributes:newAttrs range:range];
    }];

    return output;
}

- (NSAttributedString *)targetRepresentationWithIntermediateRepresentation:(NSAttributedString *)input {
    NSMutableAttributedString *output = [input mutableCopy];
    NSRange totalRange = NSMakeRange (0, input.length);
    [input enumerateAttributesInRange:totalRange options:0 usingBlock:^(NSDictionary *attrs, NSRange range, BOOL *stop) {
        NSMutableDictionary *newAttrs = [NSMutableDictionary dictionaryWithCapacity:[attrs count]];
        for (NSString *attrName in attrs) {
            id attr = [attrs objectForKey: attrName];
            if ([attrName isEqualToString:AshtonAttrParagraph]) {
                // consumes: paragraph
                NSDictionary *attrDict = attr;
                NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle defaultParagraphStyle] mutableCopy];

                if ([[attrDict objectForKey:AshtonParagraphAttrTextAlignment] isEqualToString:@"left"]) paragraphStyle.alignment = NSLeftTextAlignment;
                if ([[attrDict objectForKey:AshtonParagraphAttrTextAlignment] isEqualToString:@"right"]) paragraphStyle.alignment = NSRightTextAlignment;
                if ([[attrDict objectForKey:AshtonParagraphAttrTextAlignment] isEqualToString:@"center"]) paragraphStyle.alignment = NSCenterTextAlignment;
                if ([[attrDict objectForKey:AshtonParagraphAttrTextAlignment] isEqualToString:@"justified"]) paragraphStyle.alignment = NSJustifiedTextAlignment;

                [newAttrs setObject:[paragraphStyle copy] forKey: NSParagraphStyleAttributeName];
            }
            if ([attrName isEqualToString:AshtonAttrFont]) {
                // consumes: font
                NSDictionary *attrDict = attr;
                NSFont *font = [AshtonUtils CTFontRefWithFamilyName:[attrDict objectForKey:AshtonFontAttrFamilyName]
                                                     postScriptName:[attrDict objectForKey:AshtonFontAttrPostScriptName]
                                                               size:[[attrDict objectForKey:AshtonFontAttrPointSize] doubleValue]
                                                          boldTrait:[[attrDict objectForKey:AshtonFontAttrTraitBold] isEqual:@(YES)]
                                                        italicTrait:[[attrDict objectForKey:AshtonFontAttrTraitItalic] isEqual:@(YES)]
                                                           features:[attrDict objectForKey:AshtonFontAttrFeatures]];
                if (font) {
					[newAttrs setObject:font forKey:NSFontAttributeName];
					CFRelease(font);
				}
            }
            if ([attrName isEqualToString:AshtonAttrVerticalAlign]) {
                [newAttrs setObject:attr forKey:NSSuperscriptAttributeName];
            }
            if ([attrName isEqualToString:AshtonAttrBaselineOffset]) {
                [newAttrs setObject:attr forKey:NSBaselineOffsetAttributeName];
            }
            if ([attrName isEqualToString:AshtonAttrUnderline]) {
                // consumes: underline
                if ([attr isEqualToString:AshtonUnderlineStyleSingle]) [newAttrs setObject:@(NSUnderlineStyleSingle) forKey:NSUnderlineStyleAttributeName];
                if ([attr isEqualToString:AshtonUnderlineStyleThick]) [newAttrs setObject:@(NSUnderlineStyleThick) forKey:NSUnderlineStyleAttributeName];
                if ([attr isEqualToString:AshtonUnderlineStyleDouble]) [newAttrs setObject:@(NSUnderlineStyleDouble) forKey:NSUnderlineStyleAttributeName];
            }
            if ([attrName isEqualToString:AshtonAttrUnderlineColor]) {
                // consumes: underlineColor
                [newAttrs setObject:[self colorForArray:attr] forKey:NSUnderlineColorAttributeName];
            }
            if ([attrName isEqualToString:AshtonAttrColor]) {
                // consumes: color
                [newAttrs setObject:[self colorForArray:attr] forKey:NSForegroundColorAttributeName];
            }
            if ([attrName isEqualToString:AshtonAttrStrikethrough]) {
                // consumes: strikethrough
                if ([attr isEqualToString:AshtonStrikethroughStyleSingle]) [newAttrs setObject:@(NSUnderlineStyleSingle) forKey:NSStrikethroughStyleAttributeName];
                if ([attr isEqualToString:AshtonStrikethroughStyleThick]) [newAttrs setObject:@(NSUnderlineStyleThick) forKey:NSStrikethroughStyleAttributeName];
                if ([attr isEqualToString:AshtonStrikethroughStyleDouble]) [newAttrs setObject:@(NSUnderlineStyleDouble) forKey:NSStrikethroughStyleAttributeName];
            }
            if ([attrName isEqualToString:AshtonAttrStrikethroughColor]) {
                // consumes strikethroughColor
                [newAttrs setObject:[self colorForArray:attr] forKey:NSStrikethroughColorAttributeName];
            }
            if ([attrName isEqualToString:AshtonAttrLink]) {
                NSURL *URL = [NSURL URLWithString:attr];
				if (URL) {
					[newAttrs setObject:URL forKey:NSLinkAttributeName];
				}
            }
        }
        [output setAttributes:newAttrs range:range];
    }];

    return output;
}


- (NSArray *)arrayForColor:(NSColor *)color {
    NSColor *canonicalColor = [color colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];

	if (!canonicalColor) {
        // We got a color with an image pattern (e.g. windowBackgroundColor) that can't be converted to RGB.
        // So we convert it to image and extract the first px.
        // The result won't be 100% correct, but better than a completely undefined color.
        NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:1 pixelsHigh:1 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:4 bitsPerPixel:32];
        NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmapRep];

        [NSGraphicsContext saveGraphicsState];
        [NSGraphicsContext setCurrentContext:context];
        [color setFill];
        NSRectFill(NSMakeRect(0, 0, 1, 1));
        [context flushGraphics];
        [NSGraphicsContext restoreGraphicsState];
        canonicalColor = [bitmapRep colorAtX:0 y:0];
    }

    return @[ @(canonicalColor.redComponent), @(canonicalColor.greenComponent), @(canonicalColor.blueComponent), @(canonicalColor.alphaComponent) ];
}

- (NSColor *)colorForArray:(NSArray *)input {
	return [NSColor colorWithCalibratedRed:[[input objectAtIndex:0] doubleValue] green:[[input objectAtIndex:1] doubleValue] blue:[[input objectAtIndex:2] doubleValue] alpha:[[input objectAtIndex:3] doubleValue]];
}

@end
