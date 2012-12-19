//
//  DwollaOAuth2Client.m
//  DwollaOAuth
//
//  Created by Nick Schulze on 6/6/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "DwollaOAuth2Client.h"

@implementation DwollaOAuth2Client

@synthesize dwollaAPI, tokenRepository;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        tokenRepository = [[TokenRepository alloc] init];
    }
    return self;
}

-(id) initWithFrame:(CGRect)frame 
                key:(NSString*)_key
             secret:(NSString*)_secret
           redirect:(NSString*)_redirect
           response:(NSString*)_response
             scopes:(NSArray*)_scopes
               view:(UIView*)_view
           reciever:(id<IDwollaMessages>)_receiver
{
    self = [super initWithFrame:frame];
    if (self)
    {
        dwollaAPI = [DwollaAPI sharedInstance];
        key = [dwollaAPI encodedURLParameterString:_key];
        secret = [dwollaAPI encodedURLParameterString:_secret];
        [[NSUserDefaults standardUserDefaults] setObject:key forKey:@"key"];
        [[NSUserDefaults standardUserDefaults] setObject:secret forKey:@"secret"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        redirect = _redirect;
        response = _response;
        scopes = _scopes;
        superView = _view;
        receiver = _receiver;
        self.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        self.scalesPageToFit = YES;
        self.dataDetectorTypes = UIDataDetectorTypeNone;
        self.delegate = self;
        [superView addSubview:self];
    }
    return self;
}

-(void) login
{
    NSURLRequest* url = [dwollaAPI generateURLWithKey:key
                                      redirect:redirect
                                      response:response
                                        scopes:scopes];
    [self loadRequest:url];
}

-(void)logout
{
    [tokenRepository clearAccessToken];
}

-(BOOL)isAuthorized
{
    return [tokenRepository hasAccessToken];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)req navigationType:(UIWebViewNavigationType)navigationType
{
    NSMutableURLRequest *request = (NSMutableURLRequest *)req; 
    
    NSArray *urlItems = [[request.URL query] componentsSeparatedByString:@"&"];
    NSMutableArray *urlValues = [[NSMutableArray alloc] initWithCapacity:[urlItems count]];
    
    for (int i = 0; i<[urlItems count]; i++) 
    {
        NSArray *keysValues = [[urlItems objectAtIndex:i] componentsSeparatedByString:@"="];
        [urlValues insertObject:keysValues atIndex:i];
    }
    
    if([urlValues count]>0 && [self hasCode:urlValues]) 
    {
        [self requestAccessToken:[[urlValues objectAtIndex:0]objectAtIndex:1]];
        return NO;
    }
    return YES;
}

-(BOOL)hasCode:(NSMutableArray*)urlValues
{
    
    if ([[[urlValues objectAtIndex:0] objectAtIndex:0] isEqualToString:@"error"]) 
    {
        [receiver failedLogin:urlValues];
        return NO;
    }
    else if ([[[urlValues objectAtIndex:0] objectAtIndex:0] isEqualToString:@"code"]) 
    {
        return YES;
    }
    return NO;
}

-(void)requestAccessToken:(NSString*)code
{
    
    NSString* url = [NSString stringWithFormat: @"https://www.dwolla.com/oauth/v2/token?client_id=%@&client_secret=%@&grant_type=authorization_code&redirect_uri=https://www.dwolla.com&code=%@", key, secret, code];
    
    
    NSURL* fullURL = [[NSURL alloc] initWithString:url];
    
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:fullURL 
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                                                       timeoutInterval:10];
    
    [request setHTTPMethod: @"POST"];
    
    NSError *requestError;
    NSURLResponse *urlResponse = nil;
    
    
    NSData *result = [NSURLConnection sendSynchronousRequest:request returningResponse:&urlResponse error:&requestError];
    
    NSString *dataString = [[NSString alloc] initWithData:result encoding:NSASCIIStringEncoding]; 
    
    SBJsonParser *parser = [[SBJsonParser alloc] init];
    
    NSDictionary *dictionary = [parser objectWithString:dataString];
    
    NSString* token =[dictionary objectForKey:@"access_token"];
    
    token = [dwollaAPI encodedURLParameterString:token];
    
    [tokenRepository setAccessToken:token];
    
    [receiver successfulLogin];
    [self removeFromSuperview];
}


@end
