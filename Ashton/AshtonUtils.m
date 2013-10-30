#import "AshtonUtils.h"
#import <CoreText/CoreText.h>

@implementation AshtonUtils

+ (id)CTFontRefWithFamilyName:(NSString *)familyName postScriptName:(NSString *)postScriptName size:(CGFloat)pointSize boldTrait:(BOOL)isBold italicTrait:(BOOL)isItalic features:(NSArray *)features {

    NSMutableDictionary *descriptorAttributes = [NSMutableDictionary dictionaryWithCapacity:2];
    if (familyName) [descriptorAttributes setObject:familyName forKey:(id)kCTFontNameAttribute];
    if (postScriptName) [descriptorAttributes setObject:postScriptName forKey:(id)kCTFontNameAttribute];
    CTFontDescriptorRef descriptor = CTFontDescriptorCreateWithAttributes((CFDictionaryRef)(descriptorAttributes));

    if (features) {
        NSMutableArray *fontFeatures = [NSMutableArray array];
        for (NSArray *feature in features) {
            [fontFeatures addObject:
			 [NSDictionary dictionaryWithObjectsAndKeys:
			  [feature objectAtIndex:0], (id)kCTFontFeatureTypeIdentifierKey,
			  [feature objectAtIndex:1], (id)kCTFontFeatureSelectorIdentifierKey,
			  nil]];
        }
        [descriptorAttributes setObject:fontFeatures forKey:(id)kCTFontFeatureSettingsAttribute];
        CTFontDescriptorRef newDescriptor = CTFontDescriptorCreateWithAttributes((CFDictionaryRef)(descriptorAttributes));
        CFRelease(descriptor);
        descriptor = newDescriptor;
    }
	
    CTFontRef font = CTFontCreateWithFontDescriptor(descriptor, pointSize, NULL);
    CFRelease(descriptor);

    // We ignore symbolic traits when a postScriptName is given, because the postScriptName already encodes bold/italic and if we
    // specify it again as a trait we get different fonts (e.g. Helvetica-Oblique becomes Helvetica-LightOblique)
    CTFontSymbolicTraits symbolicTraits = 0; // using CTFontGetSymbolicTraits also makes CTFontCreateCopyWithSymbolicTraits fail
    if (!postScriptName && isBold) symbolicTraits = symbolicTraits | kCTFontTraitBold;
    if (!postScriptName && isItalic) symbolicTraits = symbolicTraits | kCTFontTraitItalic;
    if (symbolicTraits != 0) {
        // Unfortunately CTFontCreateCopyWithSymbolicTraits returns NULL when there are no symbolicTraits (== 0)
        // Is there a better way to detect "no" symbolic traits?
        CTFontRef newFont = CTFontCreateCopyWithSymbolicTraits(font, pointSize, NULL, symbolicTraits, symbolicTraits);
        // And even worse, if a font is defined to be "only" bold (like Arial Rounded MT Bold is) then
        // CTFontCreateCopyWithSymbolicTraits also returns NULL
        if (newFont != NULL) {
            CFRelease(font);
            font = newFont;
        }
    }
    return (id)font;
}

@end
