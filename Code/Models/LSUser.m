//
//  LYRSampleParticipant.m
//  LYRSampleData
//
//  Created by Kevin Coleman on 6/4/14.
//  Copyright (c) 2014 Layer, Inc. All rights reserved.
//

#import "LSUser.h"

@implementation LSUser

static NSString *const LSUserFullName = @"fullName";
static NSString *const LSUserEmail = @"email";
static NSString *const LSUserPassword = @"password";
static NSString *const LSUserIdentifier = @"identifier";

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)decoder {
   
    self = [super init];
    if (!self) {
        return nil;
    }
    
    self.fullName = [decoder decodeObjectForKey:LSUserFullName];
    self.email = [decoder decodeObjectForKey:LSUserEmail];
    self.password = [decoder decodeObjectForKey:LSUserPassword];
    self.identifier = [decoder decodeObjectForKey:LSUserIdentifier];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.fullName forKey:LSUserFullName];
    [encoder encodeObject:self.email forKey:LSUserEmail];
    [encoder encodeObject:self.password forKey:LSUserPassword];
    [encoder encodeObject:self.identifier forKey:LSUserIdentifier];
}

@end
