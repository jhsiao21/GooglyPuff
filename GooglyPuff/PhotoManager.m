//  PhotoManager.m
//  PhotoFilter
//
//  Created by A Magical Unicorn on A Sunday Night.
//  Copyright (c) 2014 Derek Selander. All rights reserved.
//

@import CoreImage;
@import AssetsLibrary;
#import "PhotoManager.h"

@interface PhotoManager ()
@property (nonatomic, strong) NSMutableArray *photosArray;
@property (nonatomic, strong) dispatch_queue_t concurrentPhotoQueue; ///< use for dispatch_barrier

@end

@implementation PhotoManager

+ (instancetype)sharedManager
{
    static PhotoManager *sharedPhotoManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedPhotoManager = [[PhotoManager alloc] init];
        sharedPhotoManager->_photosArray = [NSMutableArray array];
        
        //To instantiate concurrentPhotoQueue property
        sharedPhotoManager->_concurrentPhotoQueue = dispatch_queue_create("com.GooglyPuff.photoQueue", DISPATCH_QUEUE_CONCURRENT);
    });
    return sharedPhotoManager;

}

//*****************************************************************************/
#pragma mark - Unsafe Setter/Getters
//*****************************************************************************/

- (NSArray *)photos
{
    __block NSArray *array; //1
    dispatch_sync(self.concurrentPhotoQueue, ^{ //2 Dispatch synchronously onto the concurrentPhotoQueue to perform theread.
        
        array = [NSArray arrayWithArray:_photosArray];  //3
    });
    
    return array;
}

- (void)addPhoto:(Photo *)photo
{
    if (photo) { //1
        
        //2. To slove the problem, which is one thread calling the the write method addPhoto: while simultaneously another thread calls the read method pho- tos.
        dispatch_barrier_async(self.concurrentPhotoQueue, ^{
            //3 Since it’s a barrierblock,this block will never run simultaneously with any other block in concurrentPhotoQueue.
            [_photosArray addObject:photo];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                //4.Finally you post a notification that you’ve added the image.This notification should be posted from the main thread because it will do UI work, so here you dispatch another task asynchronously to the main queue for the notification.
                [self postContentAddedNotification];
            });
        });
        
    }
}

//*****************************************************************************/
#pragma mark - Public Methods
//*****************************************************************************/

- (void)downloadPhotosWithCompletionBlock:(BatchPhotoDownloadingCompletionBlock)completionBlock
{
    __block NSError *error;
    
    for (NSInteger i = 0; i < 3; i++) {
        NSURL *url;
        switch (i) {
            case 0:
                url = [NSURL URLWithString:kOverlyAttachedGirlfriendURLString];
                break;
            case 1:
                url = [NSURL URLWithString:kSuccessKidURLString];
                break;
            case 2:
                url = [NSURL URLWithString:kLotsOfFacesURLString];
                break;
            default:
                break;
        }
    
        Photo *photo = [[Photo alloc] initwithURL:url
                              withCompletionBlock:^(UIImage *image, NSError *_error) {
                                  if (_error) {
                                      error = _error;
                                  }
                              }];
    
        [[PhotoManager sharedManager] addPhoto:photo];
    }
    
    if (completionBlock) {
        completionBlock(error);
    }
}

//*****************************************************************************/
#pragma mark - Private Methods
//*****************************************************************************/

- (void)postContentAddedNotification
{
    static NSNotification *notification = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        notification = [NSNotification notificationWithName:kPhotoManagerAddedContentNotification object:nil];
    });
    
    [[NSNotificationQueue defaultQueue] enqueueNotification:notification postingStyle:NSPostASAP coalesceMask:NSNotificationCoalescingOnName forModes:nil];
}

@end
