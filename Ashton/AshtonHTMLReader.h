#import <Foundation/Foundation.h>

@interface AshtonHTMLReader : NSObject < NSXMLParserDelegate > {
	NSXMLParser *parser;
	NSMutableAttributedString *output;
	NSMutableArray *styleStack;
}

+ (instancetype)HTMLReader;

- (NSAttributedString *)attributedStringFromHTMLString:(NSString *)htmlString;

@end
