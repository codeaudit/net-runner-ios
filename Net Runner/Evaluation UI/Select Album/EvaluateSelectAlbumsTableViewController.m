//
//  EvaluateSelectAlbumsTableViewController.m
//  Net Runner
//
//  Created by Philip Dow on 7/17/18.
//  Copyright © 2018 doc.ai. All rights reserved.
//

#import "EvaluateSelectAlbumsTableViewController.h"

#import "EvaluateConfirmTableViewController.h"
#import "EvaluatePhotoAlbumTableViewCell.h"
#import "PhotoAssetsCollectionViewController.h"
#import "PHFetchResult+Extensions.h"

static NSString * const kAlbumCellIdentifier = @"AlbumCell";

@interface EvaluateSelectAlbumsTableViewController () <EvaluatePhotoAlbumTableViewCellActionTarget, PHPhotoLibraryChangeObserver>

@property PHFetchResult<PHAssetCollection *> *albums;
@property (nonatomic) NSSet<PHAssetCollection *> *selectedAlbums;
@property PHCachingImageManager *imageManager;

@property (readonly) UIBarButtonItem *nextButton;

@end

// MARK: -

@implementation EvaluateSelectAlbumsTableViewController

- (void)dealloc {
    [PHPhotoLibrary.sharedPhotoLibrary unregisterChangeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.selectedAlbums = [[NSSet alloc] init];
    self.imageManager = [[PHCachingImageManager alloc] init];
    
    if ( PHPhotoLibrary.authorizationStatus != PHAuthorizationStatusAuthorized ) {
        [self requestPhotoLibraryAccess];
    } else {
        [self fetchAlbums];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ( [segue.identifier isEqualToString:@"EvaluateSegue"] ) {
        EvaluateConfirmTableViewController *destination = (EvaluateConfirmTableViewController*)segue.destinationViewController;
        destination.data = @{
            @"bundles": self.data[@"bundles"],
            @"albums": self.selectedAlbums.allObjects,
            @"image-manager": self.imageManager
        };
    } else if ( [segue.identifier isEqualToString:@"AlbumDetailsSegue"] ) {
        PhotoAssetsCollectionViewController *destination = (PhotoAssetsCollectionViewController*)segue.destinationViewController;
        PHAssetCollection *album = self.albums[[self.tableView.indexPathForSelectedRow row]];
        
        // Fetch the album photos
    
        PHFetchOptions *fetchOptions = [[PHFetchOptions alloc] init];
        fetchOptions.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:YES]];
        fetchOptions.includeAllBurstAssets = NO;
        fetchOptions.includeHiddenAssets = NO;
        
        PHFetchResult<PHAsset*> *fetchResult = [PHAsset fetchAssetsInAssetCollection:album options:fetchOptions];
        
        destination.imageManager = self.imageManager;
        destination.title = album.localizedTitle;
        destination.assets = fetchResult.allAssets;
    }
}

- (void)setSelectedAlbums:(NSSet<PHAssetCollection *> *)selectedAlbums {
    _selectedAlbums = selectedAlbums;
    
    self.nextButton.enabled = _selectedAlbums.count > 0;
}

- (UIBarButtonItem*)nextButton {
    return self.navigationItem.rightBarButtonItem;
}

// MARK: - Fetching Albums

- (void)requestPhotoLibraryAccess {
    __weak typeof(self) weakself = self;
    
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            switch (status) {
            case PHAuthorizationStatusNotDetermined:
            case PHAuthorizationStatusRestricted:
            case PHAuthorizationStatusDenied:
                [PHPhotoLibrary.sharedPhotoLibrary registerChangeObserver:self];
                [weakself showPhotoLibraryUnauthorizedAlert];
                break;
            case PHAuthorizationStatusAuthorized:
                [weakself fetchAlbums];
                [weakself.tableView reloadData];
                break;
            }
        });
    }];
}

- (void)fetchAlbums {
    // Use PHAssetCollectionTypeSmartAlbum if we want to include smart albums later
    
    NSSortDescriptor *albumTitleSort = [NSSortDescriptor sortDescriptorWithKey:@"localizedTitle" ascending:YES selector:@selector(caseInsensitiveCompare:)];
    
    PHFetchOptions *fetchOptions = [[PHFetchOptions alloc] init];
    fetchOptions.sortDescriptors = @[albumTitleSort];
    fetchOptions.includeAllBurstAssets = NO;
    fetchOptions.includeHiddenAssets = NO;
    
    self.albums = [PHAssetCollection
        fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum
        subtype:PHAssetCollectionSubtypeAlbumRegular
        options:fetchOptions];
}

- (void)showPhotoLibraryUnauthorizedAlert {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:NSLocalizedString(@"Unable to access photo library", @"Photo library access unauthorized alert tite")
        message:NSLocalizedString(@"Please grant access to your photo library", @"Photo library access unauthorized alert message")
        preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction
        actionWithTitle:NSLocalizedString(@"Dismiss", @"Photo library access unauthorized dismiss action")
        style:UIAlertActionStyleCancel
        handler:nil]];
    
    [alert addAction:[UIAlertAction
        actionWithTitle:NSLocalizedString(@"Grant Access", @"Photo library access unauthorized grant access action")
        style:UIAlertActionStyleDefault
        handler:^(UIAlertAction * _Nonnull action) {
            [UIApplication.sharedApplication openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
        }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)photoLibraryDidChange:(PHChange *)changeInfo {
    // Only interested in the first change after authorization status has been approved
    [PHPhotoLibrary.sharedPhotoLibrary unregisterChangeObserver:self];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self fetchAlbums];
    });
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.albums.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 80.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    EvaluatePhotoAlbumTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kAlbumCellIdentifier forIndexPath:indexPath];
    PHAssetCollection *album = [self.albums objectAtIndex:indexPath.row];
    
    cell.titleLabel.font = [UIFont systemFontOfSize:[UIFont systemFontSize]];
    
    cell.accessoryType = [self.selectedAlbums containsObject:album]
        ? UITableViewCellAccessoryCheckmark
        : UITableViewCellAccessoryNone;
    
    cell.actionTarget = self;
    cell.album = album;
    
    return cell;
}

// MARK: -

- (void)didSwitchAlbum:(PHAssetCollection*)album toSelected:(BOOL)selected {
    if ( [self.selectedAlbums containsObject:album] ) {
        [[self mutableSetValueForKey:@"selectedAlbums"] removeObject:album];
    } else {
        [[self mutableSetValueForKey:@"selectedAlbums"] addObject:album];
    }
}

@end
