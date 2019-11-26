#import "Utils.h"

@implementation NSString (FlickPlus)
- (NSString *)sliceAfterLastUnderscore {
	NSUInteger lastUnderscore = [self rangeOfString:@"_" options:NSBackwardsSearch].location;
	if (lastUnderscore != NSNotFound)
		return [self substringFromIndex:lastUnderscore + 1];
	else
		return self;
}

- (NSString *)hyphensToSpaces {
	return [self stringByReplacingOccurrencesOfString:@"-" withString:@" "];
}
@end
