//
//  CameraLikeViewController.swift
//  MediaViewerDemo
//
//  Created by Yusaku Nishi on 2023/11/04.
//

import UIKit
import MediaViewer

#if swift(>=5.9)
import Photos
#else
// PHAsset does not conform to Sendable
@preconcurrency import Photos
#endif

final class CameraLikeViewController: UIViewController {
    
    private let cameraLikeView = CameraLikeView()
    
    private var assets: [PHAsset] = []
    
    // MARK: - Lifecycle
    
    override func loadView() {
        view = cameraLikeView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setUpViews()
        
        Task {
            await loadPhotos()
        }
    }
    
    private func setUpViews() {
        title = "CameraLike"
        
        // Navigation
        navigationItem.backButtonDisplayMode = .minimal
        navigationController?.setNavigationBarHidden(true, animated: false)
        
        // Subviews
        cameraLikeView.showLibraryButton.addAction(.init { [weak self] _ in
            self?.showLibrary()
        }, for: .primaryActionTriggered)
        
        cameraLikeView.toggleTabBarHiddenButton.addAction(.init { [weak self] _ in
            self?.toggleTabBarHidden()
        }, for: .primaryActionTriggered)
    }
    
    private func loadPhotos() async {
        assets = await PHImageFetcher.imageAssets()
        await showLatestPhotoAsThumbnail()
    }
    
    private func showLatestPhotoAsThumbnail() async {
        guard let latestAsset = assets.last else { return }
        
        let showLibraryButton = cameraLikeView.showLibraryButton
        let scale = view.window?.windowScene?.screen.scale ?? 3
        let latestImage = await PHImageFetcher.image(
            for: latestAsset,
            targetSize: CGSize(
                width: showLibraryButton.bounds.width * scale,
                height: showLibraryButton.bounds.height * scale
            ),
            contentMode: .aspectFill,
            resizeMode: .fast
        )
        showLibraryButton.configuration?.background.image = latestImage
    }
    
    // MARK: - Methods
    
    private func showLibrary() {
        guard !assets.isEmpty else { return }
        let mediaViewer = MediaViewerViewController(page: assets.count - 1, dataSource: self)
        navigationController?.delegate = mediaViewer
        navigationController?.pushViewController(mediaViewer, animated: true)
    }
    
    private func toggleTabBarHidden() {
        let tabBarController = self.tabBarController!
        let tabBar = tabBarController.tabBar
        tabBar.isHidden.toggle()
        
        /*
         * [Workaround]
         * After an interactive pop transition while the tabBar is hidden,
         * the toolbar appearance will be broken on the next transition.
         * Switching tabs fixed it. (Perhaps because the internal state of
         * the tabBarController may be correctly updated.)
         */
        let currentIndex = tabBarController.selectedIndex
        tabBarController.selectedIndex = 0
        tabBarController.selectedIndex = currentIndex
        
        navigationController?.view.setNeedsLayout()
        UIView.animate(withDuration: 0.3) {
            self.navigationController?.view.layoutIfNeeded()
        } completion: { _ in
            let buttonTitle = tabBar.isHidden ? "Show Tab Bar" : "Hide Tab Bar"
            self.cameraLikeView.toggleTabBarHiddenButton.configuration?.title = buttonTitle
        }
    }
}

// MARK: - MediaViewerDataSource -

extension CameraLikeViewController: MediaViewerDataSource {
    
    func numberOfMedia(in mediaViewer: MediaViewerViewController) -> Int {
        assets.count
    }
    
    func mediaViewer(
        _ mediaViewer: MediaViewerViewController,
        mediaOnPage page: Int
    ) -> Media {
        let asset = assets[page]
        return .async { await PHImageFetcher.image(for: asset) }
    }
    
    func mediaViewer(
        _ mediaViewer: MediaViewerViewController,
        mediaWidthToHeightOnPage page: Int
    ) -> CGFloat? {
        let asset = assets[page]
        let size = PHImageFetcher.imageSize(of: asset)
        guard let size, size.height > 0 else { return nil }
        return size.width / size.height
    }
    
    func transitionSourceView(
        forCurrentPageOf mediaViewer: MediaViewerViewController
    ) -> UIView? {
        cameraLikeView.showLibraryButton
    }
    
    func mediaViewer(
        _ mediaViewer: MediaViewerViewController,
        transitionSourceImageWith sourceView: UIView?
    ) -> UIImage? {
        cameraLikeView.showLibraryButton.configuration?.background.image
    }
}
