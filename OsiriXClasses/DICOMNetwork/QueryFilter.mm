//
//  ©Alex Bettarini -- all rights reserved
//  License GPLv3.0 -- see License File
//
//  At the end of 2014 the project was forked from OsiriX to become Miele-LXIV
//  The original header follows:
/*=========================================================================
  Program:   OsiriX

  Copyright (c) OsiriX Team
  All rights reserved.
  Distributed under GNU - LGPL
  
  See http://www.osirix-viewer.com/copyright.html for details.

     This software is distributed WITHOUT ANY WARRANTY; without even
     the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
     PURPOSE.
=========================================================================*/

#import "QueryFilter.h"
#import <DCM/DCM.h>

@implementation QueryFilter

+ (id)queryFilter
{
	return [[[QueryFilter alloc] initWithObject:nil ofSearchType:searchContains forKey:nil] autorelease];
}

+ (id)queryFilterWithObject:(id)object ofSearchType:(querySearchTypes)searchType forKey:(id)key
{
	return [[[QueryFilter alloc] initWithObject:object ofSearchType:searchType forKey:key] autorelease];
}

- (id) initWithObject:(id)object ofSearchType:(querySearchTypes)searchType  forKey:(id)key
{
	//NSLog(@"object: %@", [object description]);
	if (self = [super init])
    {
		_object = [object retain];
		_searchType = searchType;
		_key = [key retain];
	}
	return self;
}

- (void) dealloc
{
	[_object release];
	[_key release];
	
	[super dealloc];
}

#pragma mark -

- (id) key{
	return _key;
}

- (id) object{
	return _object;
}

- (querySearchTypes) searchType
{
	return _searchType;
}

#pragma mark -

- (void)setKey:(id)key
{
	if( _key == key)
        return;
	
	[_key release];
	_key = [key retain];
}

- (void)setObject:(id)object{
	if( _object == object)
        return;

	[_object release];
	_object = [object retain];
}
	
- (void)setSearchType:(querySearchTypes)searchType
{
	_searchType = searchType;
}

#pragma mark -

- (NSString *)filteredValue
{
	switch (_searchType)
	{
        case searchContains:
            return [NSString stringWithFormat:@"*%@*", _object];
            break;	//contains
            
        case searchStartsWith:
            return [NSString stringWithFormat:@"%@*", _object];
            break;
            
        case searchEndsWith:
            return [NSString stringWithFormat:@"*%@", _object];
            break;
            
        case searchExactMatch:
            if ([_object isKindOfClass:[NSDate class]]) //need to convert dates to strings
                return [_object descriptionWithCalendarFormat:@"%Y%m%d" timeZone:nil locale:nil];	
            else
                return _object;
            break;
        
        case searchToday:
            return [_object descriptionWithCalendarFormat:@"%Y%m%d-%Y%m%d" timeZone:nil locale:nil];  //today
            break;
        
        case searchYesterday:
            return [_object descriptionWithCalendarFormat:@"%Y%m%d-%Y%m%d" timeZone:nil locale:nil];  //Yesterday
            break;
        
        case searchBefore:
            return [NSString stringWithFormat:@"-%@", [_object descriptionWithCalendarFormat:@"%Y%m%d" timeZone:nil locale:nil]]; //before
            break;
        
        case searchAfter:
            if( [[NSUserDefaults standardUserDefaults] boolForKey: @"DICOMQueryAllowFutureQuery"])
            {
                return [NSString stringWithFormat:@"%@-", [_object descriptionWithCalendarFormat:@"%Y%m%d" timeZone:nil locale:nil]]; //after
            }
            else
            {
                return [NSString stringWithFormat:@"%@-%@", [_object descriptionWithCalendarFormat:@"%Y%m%d" timeZone:nil locale:nil], [[DCMCalendarDate date] descriptionWithCalendarFormat:@"%Y%m%d" timeZone:nil locale:nil]]; //after
            }
            break;
        
        case searchWithin:
            return [self withinDateString];
            break;
        
        case searchExactDate: 
            return [_object descriptionWithCalendarFormat:@"%Y%m%d-%Y%m%d" timeZone:nil locale:nil];
            break;
	}
	
	return nil;
}

- (NSString *)withinDateString
{
	DCMCalendarDate *endDate = [DCMCalendarDate date];
	NSCalendarDate *startDate = nil;
	
	NSString *today = [endDate dateString];
	NSString *dateRange = nil;
	
	switch ([_object intValue])
    {
        default:
        case searchWithinToday:
            return today;
            break;

        case searchWithinLast2Days:
            startDate = [endDate dateByAddingYears:0 months:0 days:-1 hours:0 minutes:0 seconds:0];
            break;

        case searchWithinLastWeek:
            startDate = [endDate dateByAddingYears:0 months:0 days:-7 hours:0 minutes:0 seconds:0];
            break;

        case searchWithinLast2Weeks:
            startDate = [endDate dateByAddingYears:0 months:0 days:-14 hours:0 minutes:0 seconds:0];
            break;

        case searchWithinLastMonth:
            startDate = [endDate dateByAddingYears:0 months:-1 days:0 hours:0 minutes:0 seconds:0];
            break;

        case searchWithinLast2Months:
            startDate = [endDate dateByAddingYears:0 months:-2 days:0 hours:0 minutes:0 seconds:0];
            break;

        case searchWithinLast3Months:
            startDate = [endDate dateByAddingYears:0 months:-3 days:0 hours:0 minutes:0 seconds:0];
            break;

        case searchWithinLastYear:
            startDate = [endDate dateByAddingYears:-1 months:0 days:0 hours:0 minutes:0 seconds:0];
            break;
	}
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey: @"DICOMQueryAllowFutureQuery"])
    {
        dateRange = [NSString stringWithFormat:@"%@-", [[DCMCalendarDate dicomDateWithDate:startDate] dateString]];
    }
    else
    {
        dateRange = [NSString stringWithFormat:@"%@-%@", [[DCMCalendarDate dicomDateWithDate:startDate] dateString], [[DCMCalendarDate date] dateString]];
    }

    return dateRange;
}
	
@end
