#import "AshtonHTMLWriter.h"
#import "AshtonIntermediate.h"

@implementation AshtonHTMLWriter

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static AshtonHTMLWriter *sharedInstance;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[AshtonHTMLWriter alloc] init];
    });
    return sharedInstance;
}

- (NSString *)HTMLStringFromAttributedString:(NSAttributedString *)input {
    NSMutableString *output = [NSMutableString string];

    for (NSAttributedString *paragraph in [self paragraphsForAttributedString:input]) {
        NSRange paragraphRange = NSMakeRange(0, paragraph.length);
        NSMutableString *paragraphOutput = [NSMutableString string];
        NSMutableDictionary *paragraphAttrs = [NSMutableDictionary dictionary];
        id paragraphStyle = [paragraph attribute:AshtonAttrParagraph atIndex:0 effectiveRange:NULL];
        if (paragraphStyle) [paragraphAttrs setObject:paragraphStyle forKey:AshtonAttrParagraph];

        [paragraph enumerateAttributesInRange:paragraphRange options:0 usingBlock:^(NSDictionary *attrs, NSRange range, BOOL *stop) {
            NSString *content = [self HTMLEscapeString:[paragraph.string substringWithRange:range]];
            if (NSEqualRanges(range, paragraphRange)) {
                [paragraphAttrs addEntriesFromDictionary:attrs];
				id link = [attrs objectForKey:AshtonAttrLink];
				NSString *linkStringValue = nil;
				if ([link isKindOfClass:[NSString class]]) {
					linkStringValue = link;
				} else if ([link isKindOfClass:[NSURL class]]) {
					linkStringValue = [link absoluteString];
				}
				linkStringValue = [self HTMLEscapeString:linkStringValue];
                if (linkStringValue) [paragraphOutput appendFormat:@"<a href='%@'>", linkStringValue];
                [paragraphOutput appendString:content];
                if (linkStringValue) [paragraphOutput appendString:@"</a>"];
            } else {
                [paragraphOutput appendString:[self openingTagForAttributes:attrs skipParagraphStyles:YES]];
                [paragraphOutput appendString:content];
                [paragraphOutput appendString:[self closingTagWithAttributes:attrs]];
            }
        }];

        [output appendString:@"<p"];
        [output appendString:[self styleStringForAttributes:paragraphAttrs skipParagraphStyles:NO]];
        [output appendString:@">"];
        [output appendString:paragraphOutput];
        [output appendString:@"</p>"];
    };

    return output;
}

- (NSString *)HTMLEscapeString:(NSString *)input {
    input = [input stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
    input = [input stringByReplacingOccurrencesOfString:@"\"" withString:@"&quot;"];
    input = [input stringByReplacingOccurrencesOfString:@"'" withString:@"&apos;"];
    input = [input stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
    input = [input stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];
    input = [input stringByReplacingOccurrencesOfString:@"\n" withString:@"<br />"];
    return input;
}

- (NSArray *)paragraphsForAttributedString:(NSAttributedString *)input {
    NSMutableArray *paragraphs = [NSMutableArray array];

    NSUInteger length = [input length];
    NSUInteger paraStart = 0, paraEnd = 0, contentsEnd = 0;
    NSRange currentRange;
    while (paraEnd < length) {
        [input.string getParagraphStart:&paraStart end:&paraEnd
                           contentsEnd:&contentsEnd forRange:NSMakeRange(paraEnd, 0)];
        currentRange = NSMakeRange(paraStart, contentsEnd - paraStart);
        if (currentRange.length > 0)
            [paragraphs addObject:[input attributedSubstringFromRange:currentRange]];
        else
            [paragraphs addObject:[[NSAttributedString alloc] init]];
    }

    return paragraphs;
}

- (NSString *)openingTagForAttributes:(NSDictionary *)attrs skipParagraphStyles:(BOOL)skipParagraphStyles {
    NSMutableString *tag = [NSMutableString string];
    [tag appendString:@"<"];
    [tag appendString:[self tagNameForAttributes:attrs]];
    [tag appendString:[self styleStringForAttributes:attrs skipParagraphStyles:skipParagraphStyles]];
    [tag appendString:@">"];
    return tag;
}

- (NSString *)styleStringForAttributes:(NSDictionary *)attrs skipParagraphStyles:(BOOL)skipParagraphStyles {
    NSDictionary *styles = [self stylesForAttributes:attrs skipParagraphStyles:skipParagraphStyles];
    NSMutableString *styleString = [NSMutableString string];
    if ([styles count] > 0) {
        [styleString appendString:@" style='"];
        NSArray *sortedKeys = [self sortedStyleKeyArray:[styles allKeys]];
        for (NSString *key in sortedKeys) {
            id obj = [styles objectForKey:key];
            [styleString appendString:key];
            [styleString appendString:@": "];
            if ([obj respondsToSelector:@selector(stringValue)]) obj = [obj stringValue];
            [styleString appendString:obj];
            [styleString appendString:@"; "];
        }
        [styleString appendString:@"'"];
    }

    if(skipParagraphStyles && [attrs objectForKey:AshtonAttrLink]) {
        id link = [attrs objectForKey:AshtonAttrLink];
        NSString *linkStringValue = nil;
        if ([link isKindOfClass:[NSString class]]) {
            linkStringValue = link;
        } else if ([link isKindOfClass:[NSURL class]]) {
            linkStringValue = [link absoluteString];
        }
        linkStringValue = [self HTMLEscapeString:linkStringValue];
        [styleString appendFormat:@" href='%@'", linkStringValue];
    }

    return styleString;
}

// Order style keys so that -cocoa styles come after standard styles
- (NSArray *)sortedStyleKeyArray:(NSArray *)keys {
    return [keys sortedArrayUsingComparator:^NSComparisonResult(NSString *obj1, NSString *obj2) {
        if (obj1.length > 0 && obj2.length > 0) {
            unichar char1 = [obj1 characterAtIndex:0];
            unichar char2 = [obj2 characterAtIndex:0];
            if (char1 == '-' && char2 != '-')
                return NSOrderedDescending;
            if (char1 != '-' && char2 == '-')
                return NSOrderedAscending;
        }
        return [obj1 caseInsensitiveCompare: obj2];
    }];
}

- (NSString *)closingTagWithAttributes:(NSDictionary *)attrs {
    NSMutableString *tag = [NSMutableString string];
    [tag appendString:@"</"];
    [tag appendString:[self tagNameForAttributes:attrs]];
    [tag appendString:@">"];
    return tag;
}

- (NSString *)tagNameForAttributes:(NSDictionary *)attrs {
    if ([attrs objectForKey:AshtonAttrLink]) {
        return @"a";
    }
    return @"span";
}

- (NSDictionary *)stylesForAttributes:(NSDictionary *)attrs skipParagraphStyles:(BOOL)skipParagraphStyles {
    NSMutableDictionary *styles = [NSMutableDictionary dictionary];
    for (id key in attrs) {
        if(skipParagraphStyles && [key isEqualToString:AshtonAttrParagraph]) continue;
        [styles addEntriesFromDictionary:[self stylesForAttribute:[attrs objectForKey:key] withName:key]];
    }
    return styles;
}

- (NSDictionary *)stylesForAttribute:(id)attr withName:(NSString *)attrName {
    NSMutableDictionary *styles = [NSMutableDictionary dictionary];

    if ([attrName isEqualToString:AshtonAttrParagraph]) {
        NSDictionary *attrDict = attr;
        if ([[attrDict objectForKey:AshtonParagraphAttrTextAlignment] isEqualToString:AshtonParagraphAttrTextAlignmentStyleLeft]) [styles setObject:@"left" forKey:@"text-align"];
        if ([[attrDict objectForKey:AshtonParagraphAttrTextAlignment] isEqualToString:AshtonParagraphAttrTextAlignmentStyleRight]) [styles setObject:@"right" forKey:@"text-align"];
        if ([[attrDict objectForKey:AshtonParagraphAttrTextAlignment] isEqualToString:AshtonParagraphAttrTextAlignmentStyleCenter]) [styles setObject:@"center" forKey:@"text-align"];
        if ([[attrDict objectForKey:AshtonParagraphAttrTextAlignment] isEqualToString:AshtonParagraphAttrTextAlignmentStyleJustified]) [styles setObject:@"justify" forKey:@"text-align"];
    }
    if ([attrName isEqualToString:AshtonAttrFont]) {
        NSDictionary *attrDict = attr;
        // see https://developer.mozilla.org/en-US/docs/CSS/font
        NSMutableArray *fontStyle = [NSMutableArray array];

        if ([[attrDict objectForKey:AshtonFontAttrTraitBold] isEqual:@(YES)]) [fontStyle addObject:@"bold"];
        if ([[attrDict objectForKey:AshtonFontAttrTraitItalic] isEqual:@(YES)]) [fontStyle addObject:@"italic"];

        [fontStyle addObject:[NSString stringWithFormat:@"%gpx", [[attrDict objectForKey:AshtonFontAttrPointSize] floatValue]]];
        [fontStyle addObject:[NSString stringWithFormat:@"\"%@\"", [attrDict objectForKey:AshtonFontAttrFamilyName]]];
        [styles setObject:[fontStyle componentsJoinedByString:@" "] forKey:AshtonAttrFont];

        NSMutableArray *fontFeatures = [attrDict objectForKey:AshtonFontAttrFeatures];
        if ([fontFeatures count] > 0) {
            NSMutableArray *features = [NSMutableArray array];
            for (NSArray *feature in fontFeatures) {
                [features addObject:[NSString stringWithFormat:@"%@/%@", [feature objectAtIndex:0], [feature objectAtIndex:1]]];
            }
            [styles setObject:[features componentsJoinedByString:@" "] forKey:@"-cocoa-font-features"];
        }
        if ([attrDict objectForKey:AshtonFontAttrPostScriptName]) {
            [styles setObject:[NSString stringWithFormat:@"\"%@\"", [attrDict objectForKey:AshtonFontAttrPostScriptName]] forKey:@"-cocoa-font-postscriptname"];
        }
    }
    if ([attrName isEqualToString:AshtonAttrVerticalAlign]) {
        NSInteger integerValue = [attr integerValue];
        if (integerValue < 0) [styles setObject:@"sub" forKey:@"vertical-align"];
        if (integerValue > 0) [styles setObject:@"super" forKey:@"vertical-align"];
        if (integerValue != 0) [styles setObject:@(integerValue) forKey:@"-cocoa-vertical-align"];
    }
    if ([attrName isEqualToString:AshtonAttrBaselineOffset]) {
        [styles setObject:@([attr floatValue]) forKey:@"-cocoa-baseline-offset"];
    }
    if ([attrName isEqualToString:AshtonAttrUnderline]) {
        [styles setObject:@"underline" forKey:@"text-decoration"];

        if ([attr isEqualToString:AshtonUnderlineStyleSingle]) [styles setObject:@"single" forKey:@"-cocoa-underline"];
        if ([attr isEqualToString:AshtonUnderlineStyleThick]) [styles setObject:@"thick" forKey:@"-cocoa-underline"];
        if ([attr isEqualToString:AshtonUnderlineStyleDouble]) [styles setObject:@"double" forKey:@"-cocoa-underline"];
    }
    if ([attrName isEqualToString:AshtonAttrUnderlineColor]) {
        [styles setObject:[self CSSColor:attr] forKey:@"-cocoa-underline-color"];
    }
    if ([attrName isEqualToString:AshtonAttrColor]) {
        [styles setObject:[self CSSColor:attr] forKey:AshtonAttrColor];
    }

    if ([attrName isEqualToString:AshtonAttrStrikethrough]) {
        [styles setObject:@"line-through" forKey:@"text-decoration"];

        if ([attr isEqualToString:AshtonStrikethroughStyleSingle]) [styles setObject:@"single" forKey:@"-cocoa-strikethrough"];
        if ([attr isEqualToString:AshtonStrikethroughStyleThick]) [styles setObject:@"thick" forKey:@"-cocoa-strikethrough"];
        if ([attr isEqualToString:AshtonStrikethroughStyleDouble]) [styles setObject:@"double" forKey:@"-cocoa-strikethrough"];
    }
    if ([attrName isEqualToString:AshtonAttrStrikethroughColor]) {
        [styles setObject:[self CSSColor:attr] forKey:@"-cocoa-strikethrough-color"];
    }
    
    return styles;
}

- (NSString *)CSSColor:(NSArray *)color {
    return [NSString stringWithFormat:@"rgba(%i, %i, %i, %f)", (int)([[color objectAtIndex:0] doubleValue] * 255), (int)([[color objectAtIndex:1] doubleValue] * 255), (int)([[color objectAtIndex:2] doubleValue] * 255), [[color objectAtIndex:3] doubleValue]];
}

@end
