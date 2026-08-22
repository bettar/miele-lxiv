// NSUserDefaults+Defaults.h
//
//  ©Alex Bettarini -- all rights reserved
//  License GPLv3.0 -- see License File

#import <Cocoa/Cocoa.h>

@interface NSUserDefaults (Defaults)
- (NSInteger)integerForKey:(NSString *)key default:(NSInteger)defaultValue;
- (float)floatForKey:(NSString *)key default:(float)defaultValue;
- (double)doubleForKey:(NSString *)key default:(double)defaultValue;
- (BOOL)boolForKey:(NSString *)key default:(BOOL)defaultValue;
- (NSColor*)colorForKey:(NSString *)key default:(NSColor*)defaultValue;
- (NSRect)rectForKey:(NSString *)key default:(NSRect)defaultValue;
@end
