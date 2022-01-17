//
//  ©Alex Bettarini -- all rights reserved
//  License GPLv3.0 -- see License File
//
//  LogEntry.h
//
//  Created by Alessandro Bettarini on 17 Jan 2022
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@interface LogEntry : NSManagedObject

@end

@interface LogEntry (CoreDataProperties)

+ (NSFetchRequest<LogEntry *> *)fetchRequest NS_SWIFT_NAME(fetchRequest());

@property (nullable, nonatomic, copy) NSString *destinationName;
@property (nullable, nonatomic, copy) NSString *destinationPort;
@property (nullable, nonatomic, copy) NSString *message;
@property (nullable, nonatomic, copy) NSString *destinationHostname;
@property (nullable, nonatomic, copy) NSString *originName;
@property (nullable, nonatomic, copy) NSString *originHostname;
@property (nullable, nonatomic, copy) NSString *type;
@property (nullable, nonatomic, copy) NSString *studyName;
@property (nullable, nonatomic, copy) NSNumber *numberError;
@property (nullable, nonatomic, copy) NSString *patientName;
@property (nullable, nonatomic, copy) NSNumber *numberPending;
@property (nullable, nonatomic, copy) NSDate *endTime;
@property (nullable, nonatomic, copy) NSNumber *numberImages;
@property (nullable, nonatomic, copy) NSNumber *numberSent;
@property (nullable, nonatomic, copy) NSDate *startTime;
@property (nullable, nonatomic, copy) NSString *originPort;
@property (nullable, nonatomic, copy) NSString *status;

@end

NS_ASSUME_NONNULL_END

