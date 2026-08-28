// NSUserDefaults+Defaults.mm
//
//  ©Alex Bettarini -- all rights reserved
//  License GPLv3.0 -- see License File

@implementation NSUserDefaults (Defaults)

- (NSInteger)integerForKey:(NSString *)key default:(NSInteger)defaultValue {
    NSNumber* num = [self objectForKey:key];
    return [num isKindOfClass:[NSNumber class]] ? [num integerValue] : defaultValue;
}

- (float)floatForKey:(NSString *)key default:(float)defaultValue {
    NSNumber* num = [self objectForKey:key];
    return [num isKindOfClass:[NSNumber class]] ? [num floatValue] : defaultValue;
}

- (double)doubleForKey:(NSString *)key default:(double)defaultValue {
    NSNumber* num = [self objectForKey:key];
    return [num isKindOfClass:[NSNumber class]] ? [num doubleValue] : defaultValue;
}

- (BOOL)boolForKey:(NSString *)key default:(BOOL)defaultValue {
    NSNumber* num = [self objectForKey:key];
    return [num isKindOfClass:[NSNumber class]] ? [num boolValue] : defaultValue;
}

- (NSColor*)colorForKey:(NSString *)key default:(NSColor*)defaultValue {
    NSData* data = [self objectForKey:key];
    if ([data isKindOfClass:[NSData class]]) {
        NSColor* color = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSColor class] 
                                                             fromData:data error:NULL];
        return color ?: defaultValue;
    }
    return defaultValue;
}

- (NSRect)rectForKey:(NSString *)key default:(NSRect)defaultValue {
    NSValue* val = [self objectForKey:key];
    return [val isKindOfClass:[NSValue class]] ? [val rectValue] : defaultValue;
}

@end