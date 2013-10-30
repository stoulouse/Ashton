#import "AshtonUIKit.h"
#import "AshtonIntermediate.h"
#import "AshtonUtils.h"
#import <CoreText/CoreText.h>

@interface AshtonUIKit ()
@property (nonatomic, readonly) NSArray *attributesToPreserve;
@end

@implementation AshtonUIKit

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static AshtonUIKit *sharedInstance;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[AshtonUIKit alloc] init];
    });
    return sharedInstance;
}

- (id)init {
    if (self = [super init]) {
        _attributesToPreserve = [[NSArray arrayWithObjects: AshtonAttrBaselineOffset, AshtonAttrLink, AshtonAttrStrikethroughColor, AshtonAttrUnderlineColor, AshtonAttrVerticalAlign, nil ] retain];
    }
    return self;
}

- (NSAttributedString *)intermediateRepresentationWithTargetRepresentation:(NSAttributedString *)input {
    NSMutableAttributedString *output = [input mutableCopy];
    NSRange totalRange = NSMakeRange (0, input.length);
    [input enumerateAttributesInRange:totalRange options:0 usingBlock:^(NSDictionary *attrs, NSRange range, BOOL *stop) {
        NSMutableDictionary *newAttrs = [NSMutableDictionary dictionaryWithCapacity:[attrs count]];
        for (id attrName in attrs) {
            id attr = [attrs objectForKey:attrName];
            if ([attrName isEqual:NSParagraphStyleAttributeName]) {
                // produces: paragraph
                if (![attr isKindOfClass:[NSParagraphStyle class]]) continue;
                NSParagraphStyle *paragraphStyle = attr;
                NSMutableDictionary *attrDict = [NSMutableDictionary dictionary];
				
                if (paragraphStyle.alignment == NSTextAlignmentLeft) attrDict[AshtonParagraphAttrTextAlignment] = @"left";
                if (paragraphStyle.alignment == NSTextAlignmentRight) attrDict[AshtonParagraphAttrTextAlignment] = @"right";
                if (paragraphStyle.alignment == NSTextAlignmentCenter) attrDict[AshtonParagraphAttrTextAlignment] = @"center";
                if (paragraphStyle.alignment == NSTextAlignmentJustified) attrDict[AshtonParagraphAttrTextAlignment] = @"justified";
                [newAttrs setObject:attrDict forKey:AshtonAttrParagraph];
            }
            if ([attrName isEqual:NSFontAttributeName]) {
                // produces: font
                if (![attr isKindOfClass:[UIFont class]]) continue;
                UIFont *font = attr;
                NSMutableDictionary *attrDict = [NSMutableDictionary dictionary];
				
				CGFloat scale = [UIApplication sharedApplication].keyWindow.screen.scale;
                CTFontRef ctFont = CTFontCreateWithName(( CFStringRef)font.fontName, font.pointSize * scale, NULL);
                CTFontSymbolicTraits symbolicTraits = CTFontGetSymbolicTraits(ctFont);
                if ((symbolicTraits & kCTFontTraitBold) == kCTFontTraitBold) [attrDict setObject:[NSNumber numberWithBool:YES] forKey:AshtonFontAttrTraitBold];
                if ((symbolicTraits & kCTFontTraitItalic) == kCTFontTraitItalic) [attrDict setObject:[NSNumber numberWithBool:YES] forKey:AshtonFontAttrTraitItalic];
				
                [attrDict setObject:[NSNumber numberWithFloat:font.pointSize * scale] forKey:AshtonFontAttrPointSize];
                [attrDict setObject:(NSString*)CTFontCopyName(ctFont, kCTFontFamilyNameKey) forKey:AshtonFontAttrFamilyName];
                [attrDict setObject:(NSString*)CTFontCopyName(ctFont, kCTFontPostScriptNameKey) forKey:AshtonFontAttrPostScriptName];
                CFRelease(ctFont);
                [newAttrs setObject:attrDict forKey:AshtonAttrFont];
            }
            if ([attrName isEqual:NSUnderlineStyleAttributeName]) {
                // produces: underline
                if (![attr isKindOfClass:[NSNumber class]]) continue;
                if ([attr isEqual:[NSNumber numberWithInt:NSUnderlineStyleSingle]]) [newAttrs setObject:AshtonUnderlineStyleSingle forKey:AshtonAttrUnderline];
            }
            if ([attrName isEqual:NSStrikethroughStyleAttributeName]) {
                // produces: strikthrough
                if (![attr isKindOfClass:[NSNumber class]]) continue;
                if ([attr isEqual:[NSNumber numberWithInt:NSUnderlineStyleSingle]]) [newAttrs setObject:AshtonStrikethroughStyleSingle forKey:AshtonAttrStrikethrough];
            }
            if ([attrName isEqual:NSForegroundColorAttributeName]) {
                // produces: color
                if (![attr isKindOfClass:[UIColor class]]) continue;
                [newAttrs setObject:[self arrayForColor:attr] forKey:AshtonAttrColor];
            }
        }
        // after going through all UIKit attributes copy back the preserved attributes, but only if they don't exist already
        // we don't want to overwrite settings that were assigned by UIKit with our preserved attributes
        for (id attrName in attrs) {
            id attr = attrs[attrName];
            if ([self.attributesToPreserve containsObject:attrName]) {
                if(![newAttrs objectForKey:attrName]) [newAttrs setObject:attr forKey:attrName];
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
            id attr = [attrs objectForKey:attrName];
            if ([attrName isEqualToString:AshtonAttrParagraph]) {
                // consumes: paragraph
                NSDictionary *attrDict = attr;
                NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
				
                if ([attrDict[AshtonParagraphAttrTextAlignment] isEqualToString:@"left"])  paragraphStyle.alignment = NSTextAlignmentLeft;
                if ([attrDict[AshtonParagraphAttrTextAlignment] isEqualToString:@"right"]) paragraphStyle.alignment = NSTextAlignmentRight;
                if ([attrDict[AshtonParagraphAttrTextAlignment] isEqualToString:@"center"]) paragraphStyle.alignment = NSTextAlignmentCenter;
                if ([attrDict[AshtonParagraphAttrTextAlignment] isEqualToString:@"justified"]) paragraphStyle.alignment = NSTextAlignmentJustified;
				
                [newAttrs setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
            } else if ([attrName isEqualToString:AshtonAttrFont]) {
                // consumes: font
                NSDictionary *attrDict = attr;
				
				CGFloat pointSize = [[attrDict objectForKey:AshtonFontAttrPointSize] doubleValue];
                CTFontRef ctFont = ( CTFontRef)([AshtonUtils CTFontRefWithFamilyName:[attrDict objectForKey:AshtonFontAttrFamilyName]
																	  postScriptName:[attrDict objectForKey:AshtonFontAttrPostScriptName]
																				size:pointSize
																		   boldTrait:[[attrDict objectForKey:AshtonFontAttrTraitBold] isEqual:[NSNumber numberWithBool:YES]]
																		 italicTrait:[[attrDict objectForKey:AshtonFontAttrTraitItalic] isEqual:[NSNumber numberWithBool:YES]]
																			features:[attrDict objectForKey:AshtonFontAttrFeatures]]);
				
                if (ctFont) {
                    // We need to construct a kCTFontPostScriptNameKey for the font with the given attributes
                    NSString *fontName = (NSString*)CTFontCopyName(ctFont, kCTFontPostScriptNameKey);
                    UIFont *font = [UIFont fontWithName:fontName size:pointSize];
					
                    if (font) [newAttrs setObject:font forKey:NSFontAttributeName];
					CFRelease(ctFont);
                } else {
                    // assign system font with requested size
                    [newAttrs setObject:[UIFont systemFontOfSize:pointSize] forKey:NSFontAttributeName];
                }
            } else if ([attrName isEqualToString:AshtonAttrUnderline]) {
                // consumes: underline
                if ([attr isEqualToString:AshtonUnderlineStyleSingle]) [newAttrs setObject:[NSNumber numberWithInt:NSUnderlineStyleSingle] forKey:NSUnderlineStyleAttributeName];
                if ([attr isEqualToString:AshtonUnderlineStyleDouble]) [newAttrs setObject:[NSNumber numberWithInt:NSUnderlineStyleSingle] forKey:NSUnderlineStyleAttributeName];
                if ([attr isEqualToString:AshtonUnderlineStyleThick]) [newAttrs setObject:[NSNumber numberWithInt:NSUnderlineStyleSingle] forKey: NSUnderlineStyleAttributeName];
            } else if ([attrName isEqualToString:AshtonAttrStrikethrough]) {
                if ([attr isEqualToString:AshtonStrikethroughStyleSingle]) [newAttrs setObject:[NSNumber numberWithInt:NSUnderlineStyleSingle] forKey:NSStrikethroughStyleAttributeName];
                if ([attr isEqualToString:AshtonStrikethroughStyleDouble]) [newAttrs setObject:[NSNumber numberWithInt:NSUnderlineStyleSingle] forKey:NSStrikethroughStyleAttributeName];
                if ([attr isEqualToString:AshtonStrikethroughStyleThick]) [newAttrs setObject:[NSNumber numberWithInt:NSUnderlineStyleSingle] forKey:NSStrikethroughStyleAttributeName];
            } else if ([attrName isEqualToString:AshtonAttrColor]) {
                // consumes: color
                [newAttrs setObject:[self colorForArray:attr] forKey:NSForegroundColorAttributeName];
            }
			if ([self.attributesToPreserve isKindOfClass:[NSArray class]]) {
				if ([self.attributesToPreserve containsObject:attrName]) {
					[newAttrs setObject:attr forKey:attrName];
				}
			} else {
				NSLog(@"what the fuck");
			}
        }
        [output setAttributes:newAttrs range:range];
    }];
	
    return output;
}

- (NSArray *)arrayForColor:(UIColor *)color {
    CGFloat red, green, blue, alpha;
    [color getRed:&red green:&green blue:&blue alpha:&alpha];
    return [NSArray arrayWithObjects: [NSNumber numberWithFloat:red], [NSNumber numberWithFloat:green], [NSNumber numberWithFloat:blue], [NSNumber numberWithFloat:alpha], nil ];
}

- (UIColor *)colorForArray:(NSArray *)input {
    CGFloat red = [[input objectAtIndex:0] doubleValue], green = [[input objectAtIndex:1] doubleValue], blue = [[input objectAtIndex:2] doubleValue], alpha = [[input objectAtIndex:3] doubleValue];
    return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}

@end
