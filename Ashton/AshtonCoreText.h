#import <Foundation/Foundation.h>

#import "AshtonConverter.h"

@interface AshtonCoreText : NSObject < AshtonConverter > {
	NSArray *_attributesToPreserve;
}

+ (instancetype)sharedInstance;

- (NSAttributedString *)intermediateRepresentationWithTargetRepresentation:(NSAttributedString *)input;
- (NSAttributedString *)targetRepresentationWithIntermediateRepresentation:(NSAttributedString *)input;

@end
