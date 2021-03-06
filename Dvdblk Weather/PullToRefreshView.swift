//
// PullToRefreshView.swift
//
// Copyright (c) 2014 Josip Cavar
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import UIKit
import QuartzCore


private let pullToRefreshTag = 324
private let pullToRefreshDefaultHeight: CGFloat = 80
private var KVOContext = "RefresherKVOContext"
private let ContentOffsetKeyPath = "contentOffset"

public enum PullToRefreshViewState {

    case Default
    case Loading
    case PullToRefresh
    case ReleaseToRefresh
}

public protocol PullToRefreshViewDelegate {
    
    func pullToRefreshAnimationDidStart(view: PullToRefreshView)
    func pullToRefreshAnimationDidEnd(view: PullToRefreshView)
    func pullToRefresh(view: PullToRefreshView, stateDidChange state: PullToRefreshViewState)
}

public class PullToRefreshView: UIView {
    
    var pullState = PullToRefreshViewState.Default
    
    private var scrollViewBouncesDefaultValue: Bool = false
    private var scrollViewInsetsDefaultValue: UIEdgeInsets = UIEdgeInsetsZero

    private var animator: PullToRefreshViewDelegate
    private var action: (() -> ()) = {}

    private var previousOffset: CGFloat = 0

    internal var loading: Bool = false {
        didSet {
            if loading != oldValue {
                if loading {
                    startAnimating()
                } else {
                    stopAnimating()
                }
            }
        }
    }
    
    
    //MARK: Object lifecycle methods

    convenience init(action :(() -> ()), frame: CGRect, animator: PullToRefreshViewDelegate, subview: UIView) {
        self.init(frame: frame, animator: animator)
        self.action = action;
        subview.frame = self.bounds
        addSubview(subview)
    }
    
    convenience init(action :(() -> ()), frame: CGRect, animator: PullToRefreshViewDelegate) {
        self.init(frame: frame, animator: animator)
        self.action = action;
    }
    
    init(frame: CGRect, animator: PullToRefreshViewDelegate) {
        self.animator = animator
        super.init(frame: frame)
        self.autoresizingMask = .FlexibleWidth
    }
    
    public required init?(coder aDecoder: NSCoder) {
        self.animator = RefreshAnimator(frame: CGRectZero)
        super.init(coder: aDecoder)
    }
    
    deinit {
        let scrollView = superview as? UIScrollView
        scrollView?.removeObserver(self, forKeyPath: ContentOffsetKeyPath, context: &KVOContext)
    }
    
    
    //MARK: UIView methods
    
    public override func willMoveToSuperview(newSuperview: UIView!) {
        superview?.removeObserver(self, forKeyPath: ContentOffsetKeyPath, context: &KVOContext)
        if let scrollView = newSuperview as? UIScrollView {
            scrollView.addObserver(self, forKeyPath: ContentOffsetKeyPath, options: .Initial, context: &KVOContext)
            scrollViewBouncesDefaultValue = scrollView.bounces
            scrollViewInsetsDefaultValue = scrollView.contentInset
        }
    }
    
    
    //MARK: KVO methods

	public override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
         if (context == &KVOContext) {
            if let scrollView = superview as? UIScrollView where object as? NSObject == scrollView {
                if keyPath == ContentOffsetKeyPath {
                    let offsetWithoutInsets = previousOffset + scrollViewInsetsDefaultValue.top
                    if (offsetWithoutInsets < -self.frame.size.height) {
                        if (scrollView.dragging == false && loading == false) {
                            loading = true
                        } else if (loading) {
                            self.animator.pullToRefresh(self, stateDidChange: .Loading)
                        } else {
                            self.animator.pullToRefresh(self, stateDidChange: .ReleaseToRefresh)
                        }
                    } else if (loading) {
                        self.animator.pullToRefresh(self, stateDidChange: .Loading)
                    } else if (offsetWithoutInsets < 0) {
                        self.animator.pullToRefresh(self, stateDidChange: .PullToRefresh)
                    }
                    previousOffset = scrollView.contentOffset.y
                }
            }
        } else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }
    
    
    //MARK: PullToRefreshView methods

    private func startAnimating() {
        let scrollView = superview as! UIScrollView
        var insets = scrollView.contentInset
        insets.top += self.frame.size.height
        
        // we need to restore previous offset because we will animate scroll view insets and regular scroll view animating is not applied then
        scrollView.contentOffset.y = previousOffset
        scrollView.bounces = false
        UIView.animateWithDuration(0.3, delay: 0, options: UIViewAnimationOptions(), animations: {
            scrollView.contentInset = insets
            scrollView.contentOffset = CGPointMake(scrollView.contentOffset.x, -insets.top)
        }, completion: {finished in
            self.animator.pullToRefreshAnimationDidStart(self)
            self.action()
        })
    }
    
    private func stopAnimating() {
        self.animator.pullToRefreshAnimationDidEnd(self)
        let scrollView = superview as! UIScrollView
        scrollView.bounces = self.scrollViewBouncesDefaultValue
        UIView.animateWithDuration(0.3, animations: {
            scrollView.contentInset = self.scrollViewInsetsDefaultValue
            }, completion: nil)
    }
}


extension UIScrollView {
    
    public var pullToRefreshView: PullToRefreshView? {
        get {
            let pullToRefreshView = viewWithTag(pullToRefreshTag)
            return pullToRefreshView as? PullToRefreshView
        }
    }
    
    public func addPullToRefreshWithAction(action:(() -> ()), withAnimator animator: PullToRefreshViewDelegate, withSubview subview: UIView) {
        let height = subview.frame.height
        let pullToRefreshView = PullToRefreshView(action: action, frame: CGRectMake(0, -height, self.frame.size.width, height), animator: animator, subview: subview)
        pullToRefreshView.tag = pullToRefreshTag
        addSubview(pullToRefreshView)
    }
    
    public func addPullToRefreshWithAction<T: UIView where T: PullToRefreshViewDelegate>(action:(() -> ()), withAnimator animator: T) {
        let height = animator.frame.height
        let pullToRefreshView = PullToRefreshView(action: action, frame: CGRectMake(0, -height, self.frame.size.width, height), animator: animator, subview: animator)
        pullToRefreshView.tag = pullToRefreshTag
        addSubview(pullToRefreshView)
    }
    
    // Manually start pull to refresh
    public func startPullToRefresh() {
        pullToRefreshView?.loading = true
    }
    
    // Manually stop pull to refresh
    public func stopPullToRefresh() {
        pullToRefreshView?.loading = false
    }
}
