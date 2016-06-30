//
//  ATLMAuthenticationProvider.m
//  Atlas Messenger
//
//  Created by Kevin Coleman on 5/26/16.
//  Copyright © 2016 Layer, Inc. All rights reserved.
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


#import "ATLMAuthenticationProvider.h"
#import "ATLMHTTPResponseSerializer.h"
#import "ATLMConstants.h"

NSString *const ATLMFirstNameKey = @"ATLMFirstNameKey";
NSString *const ATLMLastNameKey = @"ATLMLastNameKey";
NSString *const ATLMCredentialsKey = @"ATLMCredentialsKey";

@interface ATLMAuthenticationProvider ();

@property (nonatomic) NSURL *baseURL;
@property (nonatomic) NSURLSession *URLSession;

@end

@implementation ATLMAuthenticationProvider

@synthesize appID = _appID;

+ (nonnull instancetype)providerWithBaseURL:(nonnull NSURL *)baseURL
{
    return  [[self alloc] initWithBaseURL:baseURL];
}

- (id)initWithBaseURL:(nonnull NSURL *)baseURL;
{
    self = [super init];
    if (self) {
        _baseURL = baseURL;
    }
    return self;
}

- (void)updateWithAppID:(NSURL *)appID
{
    _appID = appID;
    _URLSession = [self defaultURLSession];
}

- (NSURLSession *)defaultURLSession
{
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    configuration.HTTPAdditionalHeaders = @{ @"Accept": @"application/json", @"X_LAYER_APP_ID": self.appID.absoluteString };
    return [NSURLSession sessionWithConfiguration:configuration];
}

- (void)authenticateWithCredentials:(NSDictionary *)credentials nonce:(NSString *)nonce completion:(void (^)(NSString *identityToken, NSError *error))completion
{
    NSString *firstName = credentials[ATLMFirstNameKey];
    NSString *lastName = credentials[ATLMLastNameKey];
    NSString *displayName = [NSString stringWithFormat:@"%@ %@", firstName, lastName];
    NSString *appUUID = [[self.appID pathComponents] lastObject];
    NSString *urlString = [NSString stringWithFormat:@"apps/%@/atlas_identities", appUUID];
    NSURL *URL = [NSURL URLWithString:urlString relativeToURL:self.baseURL];
    NSDictionary *parameters = @{ @"user" : @{ @"first_name": firstName, @"last_name": lastName, @"display_name": displayName, @"avatar_url": @"" }, @"nonce" : nonce };
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    request.HTTPMethod = @"POST";
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:parameters options:0 error:nil];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [[self.URLSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (!response && error) {
            NSLog(@"Failed with error: %@", error);
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
            return;
        }
        
        NSError *serializationError;
        NSDictionary *userDetails;
        BOOL success = [ATLMHTTPResponseSerializer responseObject:&userDetails withData:data response:(NSHTTPURLResponse *)response error:&serializationError];
        if (success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSLog(@"User JSON: %@", userDetails);
                NSString *identityToken = userDetails[ATLMAtlasIdentityTokenKey];
                completion(identityToken, nil);
            });
            [[NSUserDefaults standardUserDefaults] setValue:credentials forKey:ATLMCredentialsKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, serializationError);
            });
        }
    }] resume];
}

- (void)refreshAuthenticationWithNonce:(NSString *)nonce completion:(void (^)(NSString *identityToken, NSError *error))completion
{
    NSDictionary *credentails = [[NSUserDefaults standardUserDefaults] objectForKey:ATLMCredentialsKey];
    [self authenticateWithCredentials:credentails nonce:nonce completion:^(NSString * _Nonnull identityToken, NSError * _Nonnull error) {
        completion(identityToken, error);
    }];
}

@end
