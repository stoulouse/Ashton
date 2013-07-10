#import "AshtonHTMLReader.h"
#import "AshtonIntermediate.h"

@interface AshtonHTMLReader ()
@property (nonatomic, strong) NSXMLParser *parser;
@property (nonatomic, strong) NSMutableAttributedString *output;
@property (nonatomic, strong) NSMutableArray *styleStack;
@end

@implementation AshtonHTMLReader

@synthesize parser, output, styleStack;

+ (instancetype)HTMLReader {
    return [[AshtonHTMLReader alloc] init];
}

- (NSAttributedString *)attributedStringFromHTMLString:(NSString *)htmlString {
    self.output = [[NSMutableAttributedString alloc] init];
    self.styleStack = [NSMutableArray array];
    NSMutableString *stringToParse = [NSMutableString stringWithCapacity:(htmlString.length + 13)];
    [stringToParse appendString:@"<html>"];
    [stringToParse appendString:htmlString];
    [stringToParse appendString:@"</html>"];
    self.parser = [[NSXMLParser alloc] initWithData:[stringToParse dataUsingEncoding:NSUTF8StringEncoding]];
    self.parser.delegate = self;
    [self.parser parse];
    return self.output;
}

- (NSDictionary *)attributesForStyleString:(NSString *)styleString href:(NSString *)href {
    NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
	
    if (href) {
        [attrs setObject:href forKey:AshtonAttrLink];
    }
	
    if (styleString) {
        NSScanner *scanner = [NSScanner scannerWithString:styleString];
        while (![scanner isAtEnd]) {
            NSString *key;
            NSString *value;
            [scanner scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:NULL];
            [scanner scanUpToString:@":" intoString:&key];
            [scanner scanString:@":" intoString:NULL];
            [scanner scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:NULL];
            [scanner scanUpToString:@";" intoString:&value];
            [scanner scanString:@";" intoString:NULL];
            [scanner scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:NULL];
            if ([key isEqualToString:@"text-align"]) {
                // produces: paragraph.text-align
                NSMutableDictionary *paragraphAttrs = [attrs objectForKey:AshtonAttrParagraph];
                if (!paragraphAttrs) {
					[attrs setObject:[NSMutableDictionary dictionary] forKey:AshtonAttrParagraph];
					paragraphAttrs = [attrs objectForKey:AshtonAttrParagraph];
				}
				
                if ([value isEqualToString:@"left"]) [paragraphAttrs setObject:AshtonParagraphAttrTextAlignmentStyleLeft forKey:AshtonParagraphAttrTextAlignment];
                if ([value isEqualToString:@"right"]) [paragraphAttrs setObject:AshtonParagraphAttrTextAlignmentStyleRight forKey:AshtonParagraphAttrTextAlignment];
                if ([value isEqualToString:@"center"]) [paragraphAttrs setObject:AshtonParagraphAttrTextAlignmentStyleCenter forKey:AshtonParagraphAttrTextAlignment];
                if ([value isEqualToString:@"justify"]) [paragraphAttrs setObject:AshtonParagraphAttrTextAlignmentStyleJustified forKey:AshtonParagraphAttrTextAlignment];
            } else if ([key isEqualToString:@"vertical-align"]) {
                // produces verticalAlign
                // skip if vertical-align was already assigned by -cocoa-vertical-align
                if (![attrs objectForKey:AshtonAttrVerticalAlign]) {
                    if ([value isEqualToString:@"sub"]) [attrs setObject:@(-1) forKey:AshtonAttrVerticalAlign];
                    if ([value isEqualToString:@"super"]) [attrs setObject:@(+1) forKey:AshtonAttrVerticalAlign];
                }
            } else if ([key isEqualToString:@"-cocoa-vertical-align"]) {
                [attrs setObject:@([value integerValue]) forKey:AshtonAttrVerticalAlign];
            } else if ([key isEqualToString:@"-cocoa-baseline-offset"]) {
                [attrs setObject:@([value floatValue]) forKey:AshtonAttrBaselineOffset];
            } else if ([key isEqualToString:AshtonAttrFont]) {
                // produces: font
                NSScanner *scanner = [NSScanner scannerWithString:value];
                BOOL traitBold = [scanner scanString:@"bold " intoString:NULL];
                BOOL traitItalic = [scanner scanString:@"italic " intoString:NULL];
                NSInteger pointSize; [scanner scanInteger:&pointSize];
                [scanner scanString:@"px " intoString:NULL];
				NSString *familyName = nil;
                if ([scanner scanString:@"\\\"" intoString:NULL])
					[scanner scanUpToString:@"\\\"" intoString:&familyName];
                if ([scanner scanString:@"\"" intoString:NULL])
					[scanner scanUpToString:@"\"" intoString:&familyName];
				
//                NSDictionary *fontAttrs = @{ AshtonFontAttrTraitBold: @(traitBold), AshtonFontAttrTraitItalic: @(traitItalic), AshtonFontAttrFamilyName: familyName, AshtonFontAttrPointSize: @(pointSize), AshtonFontAttrFeatures: @[] };
				NSDictionary *fontAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
										   [NSNumber numberWithBool:traitBold], AshtonFontAttrTraitBold,
										   [NSNumber numberWithBool:traitItalic], AshtonFontAttrTraitItalic,
										   familyName, AshtonFontAttrFamilyName,
										   [NSNumber numberWithInt:pointSize], AshtonFontAttrPointSize,
										   [NSArray array], AshtonFontAttrFeatures,
				 nil];
                [attrs setObject:[self mergeFontAttributes:fontAttrs into: [attrs objectForKey:AshtonAttrFont]] forKey:AshtonAttrFont];
			}  else if ([key isEqualToString:@"-cocoa-font-postscriptname"]) {
                NSScanner *scanner = [NSScanner scannerWithString:value];
                NSString *postScriptName;
				if ([scanner scanString:@"\"" intoString:NULL])
					[scanner scanUpToString:@"\"" intoString:&postScriptName];
				if ([scanner scanString:@"\\\"" intoString:NULL])
					[scanner scanUpToString:@"\\\"" intoString:&postScriptName];
                NSDictionary *fontAttrs = @{ AshtonFontAttrPostScriptName:postScriptName };
                [attrs setObject:[self mergeFontAttributes:fontAttrs into:[attrs objectForKey:AshtonAttrFont]] forKey:AshtonAttrFont];
            } else if ([key isEqualToString:@"-cocoa-font-features"]) {
				NSMutableArray *features = [NSMutableArray array];
				for (NSString *feature in [value componentsSeparatedByString:@" "]) {
					NSArray *values = [feature componentsSeparatedByString:@"/"];
					[features addObject:@[@([[values objectAtIndex:0] integerValue]), @([[values objectAtIndex:1] integerValue])]];
				}
				
				NSDictionary *fontAttrs = @{ AshtonFontAttrFeatures: features };
				[attrs setObject:[self mergeFontAttributes:fontAttrs into:[attrs objectForKey:AshtonAttrFont]] forKey:AshtonAttrFont];
			} else if ([key isEqualToString:@"-cocoa-underline"]) {
				// produces: underline
				if ([value isEqualToString:@"single"]) [attrs setObject:AshtonUnderlineStyleSingle forKey:AshtonAttrUnderline];
				if ([value isEqualToString:@"thick"]) [attrs setObject:AshtonUnderlineStyleThick forKey:AshtonAttrUnderline];
				if ([value isEqualToString:@"double"]) [attrs setObject:AshtonUnderlineStyleDouble forKey:AshtonAttrUnderline];
			} else if ([key isEqualToString:@"text-decoration"]) {
				// produces: underline
				if ([value isEqualToString:@"none"]) {
					[attrs removeObjectForKey:AshtonUnderlineStyleSingle];
					[attrs removeObjectForKey:AshtonStrikethroughStyleSingle];
				}
				if ([value isEqualToString:@"underline"]) [attrs setObject:AshtonUnderlineStyleSingle forKey:AshtonAttrUnderline];
				if ([value isEqualToString:@"line-through"]) [attrs setObject:AshtonStrikethroughStyleSingle forKey:AshtonAttrStrikethrough];
			} else if ([key isEqualToString:@"-cocoa-underline-color"]) {
				// produces: underlineColor
				[attrs setObject:[self colorForCSS:value] forKey:AshtonAttrUnderlineColor];
			} else if ([key isEqualToString:AshtonAttrColor]) {
				// produces: color
				[attrs setObject:[self colorForCSS:value] forKey:AshtonAttrColor];
			} else if ([key isEqualToString:@"-cocoa-strikethrough"]) {
				// produces: strikethrough
				if ([value isEqualToString:@"single"]) [attrs setObject:AshtonStrikethroughStyleSingle forKey:AshtonAttrStrikethrough];
				if ([value isEqualToString:@"thick"]) [attrs setObject:AshtonStrikethroughStyleThick forKey:AshtonAttrStrikethrough];
				if ([value isEqualToString:@"double"]) [attrs setObject:AshtonStrikethroughStyleDouble forKey:AshtonAttrStrikethrough];
			} else if ([key isEqualToString:@"-cocoa-strikethrough-color"]) {
				// produces: strikethroughColor
				[attrs setObject:[self colorForCSS:value] forKey:AshtonAttrStrikethroughColor];
			} else {
				NSLog(@"unsupported html style: %@", key);
			}
        }
    }
	
    return attrs;
}

// Merge AshtonAttrFont if it already exists (e.g. if -cocoa-font-features: happened before font:)
- (NSDictionary *)mergeFontAttributes:(NSDictionary *)new into:(NSDictionary *)existing {
    if (existing) {
        NSMutableDictionary *merged = [existing mutableCopy];
        NSArray *mergedFeatures = nil;
        if ([existing objectForKey:AshtonFontAttrFeatures] && [new objectForKey:AshtonFontAttrFeatures]) {
			mergedFeatures = [[existing objectForKey:AshtonFontAttrFeatures] arrayByAddingObjectsFromArray:[new objectForKey:AshtonFontAttrFeatures]];
		}
        [merged addEntriesFromDictionary:new];
        if (mergedFeatures) {
			[merged setObject:mergedFeatures forKey:AshtonFontAttrFeatures];
		}
        return merged;
    } else {
        return new;
    }
}

- (NSDictionary *)currentAttributes {
    NSMutableDictionary *mergedAttrs = [NSMutableDictionary dictionary];
    for (NSDictionary *attrs in self.styleStack) {
        [mergedAttrs addEntriesFromDictionary:attrs];
    }
    return mergedAttrs;
}

- (void)parserDidStartDocument:(NSXMLParser *)parser {
    [self.output beginEditing];
}

- (void)parserDidEndDocument:(NSXMLParser *)parser {
    [self.output endEditing];
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
    if ([elementName isEqualToString:@"html"]) return;
    if (self.output.length > 0) {
        if ([elementName isEqualToString:@"p"]) [self.output appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
    }
    [self.styleStack addObject:[self attributesForStyleString:[attributeDict objectForKey:@"style"] href:[attributeDict objectForKey:@"href"]]];
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    if ([elementName isEqualToString:@"html"]) return;
    [self.styleStack removeLastObject];
}

- (void)parser:(NSXMLParser *)p parseErrorOccurred:(NSError *)parseError {
    NSLog(@"XMLParser error %@", [parseError localizedDescription]);
}

-(void)parser:(NSXMLParser *)parser validationErrorOccurred:(NSError *)validationError {
    NSLog(@"XMLParser error: %@", [validationError localizedDescription]);
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
	if (![string isEqualToString:@"\n"]) {
		NSMutableAttributedString *fragment = [[NSMutableAttributedString alloc] initWithString:string attributes:[self currentAttributes]];
		[self.output appendAttributedString:fragment];
	}
}

- (id)colorForCSS:(NSString *)css {
	NSScanner *scanner = [NSScanner scannerWithString:css];
	[scanner scanString:@"rgba(" intoString:NULL];
	int red; [scanner scanInt:&red];
	[scanner scanString:@", " intoString:NULL];
	int green; [scanner scanInt:&green];
	[scanner scanString:@", " intoString:NULL];
	int blue; [scanner scanInt:&blue];
	[scanner scanString:@", " intoString:NULL];
	float alpha; [scanner scanFloat:&alpha];
	
	return @[ @((float)red / 255), @((float)green / 255), @((float)blue / 255), @(alpha) ];
}
@end
