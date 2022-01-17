//
//  ©Alex Bettarini -- all rights reserved
//  License GPLv3.0 -- see License File
//
//  LogEntry.m
//
//  Created by Alessandro Bettarini on 17 Jan 2022
//

#import "LogEntry.h"

@implementation LogEntry (CoreDataProperties)

+ (NSFetchRequest<LogEntry *> *)fetchRequest {
    return [NSFetchRequest fetchRequestWithEntityName:@"LogEntry"];
}

@dynamic destinationName;
@dynamic destinationPort;
@dynamic message;
@dynamic destinationHostname;
@dynamic originName;
@dynamic originHostname;
@dynamic type;
@dynamic studyName;
@dynamic numberError;
@dynamic patientName;
@dynamic numberPending;
@dynamic endTime;
@dynamic numberImages;
@dynamic numberSent;
@dynamic startTime;
@dynamic originPort;
@dynamic status;

@end

#pragma mark -

@implementation LogEntry

@end
