#import <Foundation/Foundation.h>

@interface AshtonHTMLReader : NSObject < NSXMLParserDelegate > {
	NSXMLParser *parser;
	NSMutableAttributedString *output;
	NSMutableArray *styleStack;
	NSMutableDictionary *globalStyles;
	NSMutableString* content;
	NSString* currentElement;
}

+ (instancetype)HTMLReader;

- (NSAttributedString *)attributedStringFromHTMLString:(NSString *)htmlString;

@end
