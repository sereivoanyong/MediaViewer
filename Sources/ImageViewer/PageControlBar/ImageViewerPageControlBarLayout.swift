//
//  ImageViewerPageControlBarLayout.swift
//  
//
//  Created by Yusaku Nishi on 2023/03/18.
//

import UIKit

final class ImageViewerPageControlBarLayout: UICollectionViewLayout {
    
    enum Style {
        case expanded(IndexPath, expandingImageWidthToHeight: CGFloat?)
        case collapsed
        
        var indexPathForExpandingItem: IndexPath? {
            switch self {
            case .expanded(let indexPath, _):
                return indexPath
            case .collapsed:
                return nil
            }
        }
    }
    
    let style: Style
    
    var expandedItemWidth: CGFloat?
    static let collapsedItemWidth: CGFloat = 21
    
    private var attributesDictionary: [IndexPath: UICollectionViewLayoutAttributes] = [:]
    private var contentSize: CGSize = .zero
    
    // MARK: - Initializers
    
    init(style: Style) {
        self.style = style
        super.init()
    }
    
    required init?(coder: NSCoder) {
        self.style = .collapsed
        super.init(coder: coder)
    }
    
    // MARK: - Override
    
    override var collectionViewContentSize: CGSize {
        contentSize
    }
    
    override func prepare() {
        // Reset
        attributesDictionary.removeAll(keepingCapacity: true)
        contentSize = .zero
        
        guard let collectionView, collectionView.numberOfSections == 1 else { return }
        let numberOfItems = collectionView.numberOfItems(inSection: 0)
        guard numberOfItems > 0 else { return }
        
        // NOTE: Cache and reuse expandedItemWidth for smooth animation.
        let expandedItemWidth = self.expandedItemWidth ?? expandingItemWidth(in: collectionView)
        self.expandedItemWidth = expandedItemWidth
        
        let collapsedItemSpacing: CGFloat = 1
        let expandedItemSpacing: CGFloat = 12
        
        // Calculate frames for each item
        var frames: [IndexPath: CGRect] = [:]
        for item in 0 ..< numberOfItems {
            let indexPath = IndexPath(item: item, section: 0)
            let previousIndexPath = IndexPath(item: item - 1, section: 0)
            let width: CGFloat
            let itemSpacing: CGFloat
            switch style.indexPathForExpandingItem {
            case indexPath:
                width = expandedItemWidth
                itemSpacing = expandedItemSpacing
            case previousIndexPath:
                width = Self.collapsedItemWidth
                itemSpacing = expandedItemSpacing
            default:
                width = Self.collapsedItemWidth
                itemSpacing = collapsedItemSpacing
            }
            let previousFrame = frames[previousIndexPath]
            let x = previousFrame.map { $0.maxX + itemSpacing } ?? 0
            frames[indexPath] = CGRect(x: x,
                                       y: 0,
                                       width: width,
                                       height: collectionView.bounds.height)
        }
        
        // Calculate the content size
        let lastItemFrame = frames[IndexPath(item: numberOfItems - 1, section: 0)]!
        contentSize = CGSize(width: lastItemFrame.maxX,
                             height: collectionView.bounds.height)
        
        // Set up layout attributes
        for (indexPath, frame) in frames {
            let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            attributes.frame = frame
            attributesDictionary[indexPath] = attributes
        }
    }
    
    private func expandingItemWidth(in collectionView: UICollectionView) -> CGFloat {
        let expandingImageWidthToHeight: CGFloat
        switch style {
        case .expanded(let indexPath, let imageWidthToHeight):
            if let imageWidthToHeight {
                expandingImageWidthToHeight = imageWidthToHeight
            } else if let cell = collectionView.cellForItem(at: indexPath) {
                let cell = cell as! PageControlBarThumbnailCell
                let image = cell.imageView.image
                if let imageSize = image?.size, imageSize.height > 0 {
                    expandingImageWidthToHeight = imageSize.width / imageSize.height
                } else {
                    expandingImageWidthToHeight = 0
                }
            } else {
                expandingImageWidthToHeight = 0
            }
        case .collapsed:
            expandingImageWidthToHeight = 0
        }
        
        let minimumWidth = Self.collapsedItemWidth
        let maximumWidth: CGFloat = 84
        return min(
            max(
                collectionView.bounds.height * expandingImageWidthToHeight,
                minimumWidth
            ),
            maximumWidth
        )
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        attributesDictionary.values.filter { $0.frame.intersects(rect) }
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        attributesDictionary[indexPath]
    }
    
    override func targetContentOffset(
        forProposedContentOffset proposedContentOffset: CGPoint
    ) -> CGPoint {
        let offset = super.targetContentOffset(
            forProposedContentOffset: proposedContentOffset
        )
        guard let collectionView else { return offset }
        
        // Center the target item.
        let indexPathForCenterItem: IndexPath
        switch style {
        case .expanded(let indexPathForExpandingItem, _):
            indexPathForCenterItem = indexPathForExpandingItem
        case .collapsed:
            guard let indexPath = collectionView.indexPathForHorizontalCenterItem else {
                return offset
            }
            indexPathForCenterItem = indexPath
        }
        
        guard let centerItemAttributes = layoutAttributesForItem(at: indexPathForCenterItem) else {
            return offset
        }
        return CGPoint(
            x: centerItemAttributes.center.x - collectionView.bounds.width / 2,
            y: offset.y
        )
    }
}
