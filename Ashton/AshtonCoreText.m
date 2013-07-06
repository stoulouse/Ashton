#import "AshtonCoreText.h"
#import "AshtonIntermediate.h"
#import "AshtonUtils.h"
#import <CoreText/CoreText.h>

@interface AshtonCoreText ()
@property (nonatomic, readonly) NSArray *attributesToPreserve;
@end

@implementation AshtonCoreText

@synthesize attributesToPreserve = _attributesToPreserve;

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static AshtonCoreText *sharedInstance;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[AshtonCoreText alloc] init];
    });
    return sharedInstance;
}

- (void)dealloc {
    [_attributesToPreserve release];
    [super dealloc];
}

- (id)init {
    if (self = [super init]) {
		_attributesToPreserve = [[NSArray arrayWithObjects:AshtonAttrBaselineOffset, AshtonAttrStrikethrough, AshtonAttrStrikethroughColor, AshtonAttrLink, nil] retain];
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
            if ([attrName isEqual:(id)kCTParagraphStyleAttributeName]) {
                // produces: paragraph
                CTParagraphStyleRef paragraphStyle = ( CTParagraphStyleRef)attr;
                NSMutableDictionary *attrDict = [NSMutableDictionary dictionary];
				
                CTTextAlignment alignment;
                CTParagraphStyleGetValueForSpecifier(paragraphStyle, kCTParagraphStyleSpecifierAlignment, sizeof(alignment), &alignment);
				
                if (alignment == kCTTextAlignmentLeft) [attrDict setObject:@"left" forKey:AshtonParagraphAttrTextAlignment];
                if (alignment == kCTTextAlignmentRight) [attrDict setObject:@"right" forKey:AshtonParagraphAttrTextAlignment];
                if (alignment == kCTTextAlignmentCenter) [attrDict setObject:@"center" forKey:AshtonParagraphAttrTextAlignment];
                if (alignment == kCTTextAlignmentJustified) [attrDict setObject:@"justified" forKey:AshtonParagraphAttrTextAlignment];
                [newAttrs setObject:attrDict forKey:AshtonAttrParagraph];
            }
            if ([attrName isEqual:(id)kCTFontAttributeName]) {
                // produces: font
                CTFontRef font = (CTFontRef)attr;
                NSMutableDictionary *attrDict = [NSMutableDictionary dictionary];
				
                CTFontSymbolicTraits symbolicTraits = CTFontGetSymbolicTraits(font);
                if ((symbolicTraits & kCTFontTraitBold) == kCTFontTraitBold) [attrDict setObject:@(YES) forKey:AshtonFontAttrTraitBold];
                if ((symbolicTraits & kCTFontTraitItalic) == kCTFontTraitItalic) [attrDict setObject:@(YES) forKey:AshtonFontAttrTraitItalic];
				
                NSArray *fontFeatures = CFBridgingRelease(CTFontCopyFeatureSettings(font));
                NSMutableSet *features = [NSMutableSet set];
                for (NSDictionary *feature in fontFeatures) {
                    [features addObject:@[[feature objectForKey:(id)kCTFontFeatureTypeIdentifierKey], [feature objectForKey:(id)kCTFontFeatureSelectorIdentifierKey]]];
                }
				
                [attrDict setObject:features forKey:AshtonFontAttrFeatures];
                [attrDict setObject:@(CTFontGetSize(font)) forKey:AshtonFontAttrPointSize];
                [attrDict setObject:CFBridgingRelease(CTFontCopyName(font, kCTFontFamilyNameKey)) forKey:AshtonFontAttrFamilyName];
                [attrDict setObject:CFBridgingRelease(CTFontCopyName(font, kCTFontPostScriptNameKey)) forKey:AshtonFontAttrPostScriptName];
                [newAttrs setObject:attrDict forKey:AshtonAttrFont];
            }
            if ([attrName isEqual:(id)kCTSuperscriptAttributeName]) {
                [newAttrs setObject:@([attr integerValue]) forKey:AshtonAttrVerticalAlign];
            }
            if ([attrName isEqual:(id)kCTUnderlineStyleAttributeName]) {
                // produces: underline
                if ([attr isEqual:@(kCTUnderlineStyleSingle)]) [newAttrs setObject:AshtonUnderlineStyleSingle forKey:AshtonAttrUnderline];
                if ([attr isEqual:@(kCTUnderlineStyleThick)]) [newAttrs setObject:AshtonUnderlineStyleThick forKey:AshtonAttrUnderline];
                if ([attr isEqual:@(kCTUnderlineStyleDouble)]) [newAttrs setObject:AshtonUnderlineStyleDouble forKey:AshtonAttrUnderline];
            }
            if ([attrName isEqual:(id)kCTUnderlineColorAttributeName]) {
                // produces: underlineColor
                [newAttrs setObject:[self arrayForColor:(CGColorRef)(attr)] forKey:AshtonAttrUnderlineColor];
            }
            if ([attrName isEqual:(id)kCTForegroundColorAttributeName] || [attrName isEqual:(id)kCTStrokeColorAttributeName]) {
                // produces: color
                [newAttrs setObject:[self arrayForColor:(CGColorRef)(attr)] forKey:AshtonAttrColor];
            }
            if ([self.attributesToPreserve containsObject:attrName]) {
                [newAttrs setObject:attr forKey:attrName];
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
                CTTextAlignment alignment = kCTTextAlignmentNatural;
                if ([[attrDict objectForKey:AshtonParagraphAttrTextAlignment] isEqualToString:@"left"]) alignment = kCTTextAlignmentLeft;
                if ([[attrDict objectForKey:AshtonParagraphAttrTextAlignment] isEqualToString:@"right"]) alignment = kCTTextAlignmentRight;
                if ([[attrDict objectForKey:AshtonParagraphAttrTextAlignment] isEqualToString:@"center"]) alignment = kCTTextAlignmentCenter;
                if ([[attrDict objectForKey:AshtonParagraphAttrTextAlignment] isEqualToString:@"justified"]) alignment = kCTTextAlignmentJustified;
				
                CTParagraphStyleSetting settings[] = {
                    { kCTParagraphStyleSpecifierAlignment, sizeof(CTTextAlignment), &alignment },
                };
				
                [newAttrs setObject:CFBridgingRelease(CTParagraphStyleCreate(settings, sizeof(settings) / sizeof(CTParagraphStyleSetting))) forKey:(id)kCTParagraphStyleAttributeName];
            }
            if ([attrName isEqualToString:AshtonAttrFont]) {
                // consumes: font
                NSDictionary *attrDict = attr;
                id font = [AshtonUtils CTFontRefWithFamilyName:[attrDict objectForKey:AshtonFontAttrFamilyName]
                                                postScriptName:[attrDict objectForKey:AshtonFontAttrPostScriptName]
                                                          size:[[attrDict objectForKey:AshtonFontAttrPointSize] doubleValue]
                                                     boldTrait:[[attrDict objectForKey:AshtonFontAttrTraitBold] isEqual:@(YES)]
                                                   italicTrait:[[attrDict objectForKey:AshtonFontAttrTraitItalic] isEqual:@(YES)]
                                                      features:[attrDict objectForKey:AshtonFontAttrFeatures]];
                if (font) [newAttrs setObject:font forKey:(id)kCTFontAttributeName];
            }
            if ([attrName isEqualToString:AshtonAttrVerticalAlign]) {
                [newAttrs setObject:@([attr integerValue]) forKey:(id)kCTSuperscriptAttributeName];
            }
            if ([attrName isEqualToString:AshtonAttrUnderline]) {
                // consumes: underline
                if ([attr isEqualToString:@"single"]) [newAttrs setObject:@(kCTUnderlineStyleSingle) forKey:(id)kCTUnderlineStyleAttributeName];
                if ([attr isEqualToString:@"thick"]) [newAttrs setObject:@(kCTUnderlineStyleThick) forKey:(id)kCTUnderlineStyleAttributeName];
                if ([attr isEqualToString:@"double"]) [newAttrs setObject:@(kCTUnderlineStyleDouble) forKey:(id)kCTUnderlineStyleAttributeName];
            }
            if ([attrName isEqualToString:AshtonAttrUnderlineColor]) {
                // consumes: underlineColor
                [newAttrs setObject:[self colorForArray:attr] forKey:(id)kCTUnderlineColorAttributeName];
            }
            if ([attrName isEqualToString:AshtonAttrColor]) {
                // consumes: color
                [newAttrs setObject:[self colorForArray:attr] forKey:(id)kCTForegroundColorAttributeName];
            }
            if ([self.attributesToPreserve containsObject:attrName]) {
                [newAttrs setObject:attr forKey:attrName];
            }
        }
        [output setAttributes:newAttrs range:range];
    }];
	
    return output;
}

- (NSArray *)arrayForColor:(CGColorRef)color {
    CGFloat red, green, blue;
    CGFloat alpha = CGColorGetAlpha(color);
    const CGFloat *components = CGColorGetComponents(color);
    if (CGColorGetNumberOfComponents(color) == 2) {
        red = green = blue = components[0];
    } else if (CGColorGetNumberOfComponents(color) == 4) {
        red = components[0];
        green = components[1];
        blue = components[2];
    } else {
        red = green = blue = 0;
    }
    return @[ @(red), @(green), @(blue), @(alpha) ];
}

- (id)colorForArray:(NSArray *)input {
    const CGFloat components[] = { [[input objectAtIndex:0] doubleValue], [[input objectAtIndex:1] doubleValue], [[input objectAtIndex:2] doubleValue], [[input objectAtIndex:3] doubleValue] };
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
    id color = CFBridgingRelease(CGColorCreate(colorspace, components));
    CFRelease(colorspace);
    return color;
}

@end