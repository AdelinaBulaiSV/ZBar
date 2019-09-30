//------------------------------------------------------------------------
//  Copyright 2009-2010 (c) Jeff Brown <spadix@users.sourceforge.net>
//
//  This file is part of the ZBar Bar Code Reader.
//
//  The ZBar Bar Code Reader is free software; you can redistribute it
//  and/or modify it under the terms of the GNU Lesser Public License as
//  published by the Free Software Foundation; either version 2.1 of
//  the License, or (at your option) any later version.
//
//  The ZBar Bar Code Reader is distributed in the hope that it will be
//  useful, but WITHOUT ANY WARRANTY; without even the implied warranty
//  of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU Lesser Public License for more details.
//
//  You should have received a copy of the GNU Lesser Public License
//  along with the ZBar Bar Code Reader; if not, write to the Free
//  Software Foundation, Inc., 51 Franklin St, Fifth Floor,
//  Boston, MA  02110-1301  USA
//
//  http://sourceforge.net/projects/zbar
//------------------------------------------------------------------------

#import <ZBarSDK/ZBarHelpController.h>

#define MODULE ZBarHelpController
#import "debug.h"

@implementation ZBarHelpController

@synthesize delegate;

- (id) initWithReason: (NSString*) _reason
{
    self = [super init];
    if(!self)
        return(nil);

    if(!_reason)
        _reason = @"INFO";
    reason = [_reason retain];
    return(self);
}

- (id) init
{
    return([self initWithReason: nil]);
}

- (void) cleanup
{
    [toolbar release];
    toolbar = nil;
    [webView release];
    webView = nil;
    [doneBtn release];
    doneBtn = nil;
    [backBtn release];
    backBtn = nil;
    [space release];
    space = nil;
}

- (void) dealloc
{
    [self cleanup];
    [reason release];
    reason = nil;
    [linkURL release];
    linkURL = nil;
    [super dealloc];
}

- (void) viewDidLoad
{
    [super viewDidLoad];

    UIView *view = self.view;
    CGRect bounds = self.view.bounds;
    if(!bounds.size.width || !bounds.size.height)
        view.frame = bounds = CGRectMake(0, 0, 320, 480);
    view.backgroundColor = [UIColor colorWithWhite: .125f
                                    alpha: 1];
    view.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                             UIViewAutoresizingFlexibleHeight);

    webView = [[WKWebView alloc] initWithFrame:CGRectMake(0, 0, bounds.size.width, bounds.size.height - 44)];
    webView.UIDelegate = self;
    webView.navigationDelegate = self;
    
    webView.backgroundColor = [UIColor colorWithWhite:.125f alpha:1.0];
    webView.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                                UIViewAutoresizingFlexibleHeight |
                                UIViewAutoresizingFlexibleBottomMargin);
    webView.hidden = YES;
    [view addSubview: webView];

    toolbar = [[UIToolbar alloc]
                  initWithFrame: CGRectMake(0, bounds.size.height - 44,
                                            bounds.size.width, 44)];
    toolbar.barStyle = UIBarStyleBlackOpaque;
    toolbar.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                                UIViewAutoresizingFlexibleHeight |
                                UIViewAutoresizingFlexibleTopMargin);

    doneBtn = [[UIBarButtonItem alloc]
                  initWithBarButtonSystemItem: UIBarButtonSystemItemDone
                  target: self
                  action: @selector(dismiss)];

    backBtn = [[UIBarButtonItem alloc]
                  initWithImage: [UIImage imageNamed: @"zbar-back.png"]
                  style: UIBarButtonItemStylePlain
                  target: webView
                  action: @selector(goBack)];

    space = [[UIBarButtonItem alloc]
                initWithBarButtonSystemItem:
                    UIBarButtonSystemItemFlexibleSpace
                target: nil
                action: nil];

    toolbar.items = [NSArray arrayWithObjects: space, doneBtn, nil];

    [view addSubview: toolbar];

    NSString *path = [[NSBundle mainBundle]
                         pathForResource: @"zbar-help"
                         ofType: @"html"];

    NSURLRequest *req = nil;
    if(path) {
        NSURL *url = [NSURL fileURLWithPath: path
                            isDirectory: NO];
        if(url)
            req = [NSURLRequest requestWithURL: url];
    }
    if(req)
        [webView loadRequest: req];
    else
        NSLog(@"ERROR: unable to load zbar-help.html from bundle");
}

- (void) viewDidUnload
{
    [self cleanup];
    [super viewDidUnload];
}

- (void) viewWillAppear: (BOOL) animated
{
    assert(webView);
    if(webView.loading)
        webView.hidden = YES;
    webView.UIDelegate = self;
    webView.navigationDelegate = self;
    [super viewWillAppear: animated];
}

- (void) viewWillDisappear: (BOOL) animated
{
    [webView stopLoading];
    webView.UIDelegate = self;
    webView.navigationDelegate = self;
    [super viewWillDisappear: animated];
}

- (BOOL) shouldAutorotateToInterfaceOrientation: (UIInterfaceOrientation) orient
{
    return([self isInterfaceOrientationSupported: orient]);
}

- (void) willAnimateRotationToInterfaceOrientation: (UIInterfaceOrientation) orient
                                          duration: (NSTimeInterval) duration
{
    [webView reload];
}

- (void) didRotateFromInterfaceOrientation: (UIInterfaceOrientation) orient
{
    zlog(@"frame=%@ webView.frame=%@ toolbar.frame=%@",
         NSStringFromCGRect(self.view.frame),
         NSStringFromCGRect(webView.frame),
         NSStringFromCGRect(toolbar.frame));
}

- (BOOL) isInterfaceOrientationSupported: (UIInterfaceOrientation) orient
{
    UIViewController *parent = self.parentViewController;
    if(parent && !orientations)
        return([parent shouldAutorotateToInterfaceOrientation: orient]);
    return((orientations >> orient) & 1);
}

- (void) setInterfaceOrientation: (UIInterfaceOrientation) orient
                       supported: (BOOL) supported
{
    NSUInteger mask = 1 << orient;
    if(supported)
        orientations |= mask;
    else
        orientations &= ~mask;
}

- (void) dismiss
{
    if([delegate respondsToSelector: @selector(helpControllerDidFinish:)])
        [delegate helpControllerDidFinish: self];
    else
        [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    if (webView.hidden) {
        
//        [UIView beginAnimations: @"ZBarHelp" context: nil];
//        webView.hidden = NO;
        NSString *javaScript = [NSString stringWithFormat: @"onZBarHelp({reason:\"%@\"});", reason];
        [webView evaluateJavaScript:javaScript completionHandler:^(id _Nullable complete, NSError * _Nullable error) {
//            [UIView commitAnimations];
            if (error) {
                NSLog(@"WKWebView error: %@", error.localizedDescription);
            }
        }];
        
        BOOL canGoBack = webView.canGoBack;
        NSArray *items = toolbar.items;
        if(canGoBack != ([items objectAtIndex: 0] == backBtn)) {
            if(canGoBack) {
                items = [NSArray arrayWithObjects: backBtn, space, doneBtn, nil];
            } else {
                items = [NSArray arrayWithObjects: space, doneBtn, nil];
            }
            [toolbar setItems: items animated: YES];
        }
    }
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSURL *url = [navigationAction.request URL];
    if([url isFileURL]) {
        decisionHandler(WKNavigationActionPolicyAllow);
    }
    
    linkURL = [url retain];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Open External Link"
                                                                   message:@"Close this application and open link in Safari?"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [[UIApplication sharedApplication] openURL:linkURL options:@{} completionHandler:nil];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
    
    decisionHandler(WKNavigationActionPolicyCancel);
}

@end
