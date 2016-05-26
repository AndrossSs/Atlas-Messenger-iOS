//
//  ATLMSession.m
//  Atlas Messenger
//
//  Created by Blake Watters on 6/28/14.
//  Copyright (c) 2014 Layer, Inc. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "ATLMUserSession.h"
#import "ATLMUser.h"

@interface ATLMUserSession ()

@property (nonatomic, readwrite) NSString *authenticationToken;
@property (nonatomic, readwrite) id <ATLMAuthenticating> user;

@end

@implementation ATLMUserSession

+ (instancetype)sessionWithAuthenticationToken:(NSString *)authenticationToken user:(id <ATLMAuthenticating>)user
{
    NSParameterAssert(authenticationToken);
    NSParameterAssert(user);
    return [[self alloc] initWithAuthenticationToken:authenticationToken user:user];
}

- (id)initWithAuthenticationToken:(NSString *)authenticationToken user:(id <ATLMAuthenticating>)user
{
    self = [super init];
    if (self) {
        _authenticationToken = authenticationToken;
        _user = user;
    }
    return self;
}

- (id)init
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Failed to call designated initializer." userInfo:nil];
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)decoder
{    
    NSString *authenticationToken = [decoder decodeObjectForKey:NSStringFromSelector(@selector(authenticationToken))];
    ATLMUser *user = [decoder decodeObjectForKey:NSStringFromSelector(@selector(user))];
    return [self initWithAuthenticationToken:authenticationToken user:user];
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:self.authenticationToken forKey:NSStringFromSelector(@selector(authenticationToken))];
    [encoder encodeObject:self.user forKey:NSStringFromSelector(@selector(user))];
}

#pragma mark - NSObject

- (NSUInteger)hash
{
    return self.authenticationToken.hash;
}

- (BOOL)isEqual:(id)object
{
    if (!object) return NO;
    if (![object isKindOfClass:[ATLMUserSession class]]) return NO;
    ATLMUserSession *otherSession = object;
    if (![self.authenticationToken isEqualToString:otherSession.authenticationToken]) return NO;
    if (![self.user isEqual:otherSession.user]) return NO;
    return YES;
}

@end
