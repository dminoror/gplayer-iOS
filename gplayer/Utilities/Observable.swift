//
//  Observable.swift
//  gplayer
//
//  Created by DoubleLight on 2020/9/4.
//  Copyright © 2020 dminoror. All rights reserved.
//

import Foundation

public final class Observable<Value> {
    
    struct DidSetObserver<Value> {
        weak var observer: AnyObject?
        var block: (Value) -> Void
    }
    struct WillSetObserver<Value> {
        weak var observer: AnyObject?
        var block: (Value, Value) -> Void
    }
    
    private var didSets = [DidSetObserver<Value>]()
    private var willSets = [WillSetObserver<Value>]()
    
    public var value: Value {
        didSet {
            for observer in didSets {
                DispatchQueue.main.async {
                    observer.block(self.value)
                }
            }
        }
        willSet {
            for observer in willSets {
                DispatchQueue.main.async {
                    observer.block(newValue, self.value)
                }
            }
        }
    }
    
    public init(_ value: Value) {
        self.value = value
    }
    
    public func didSet(observer: AnyObject, observerBlock: @escaping (Value) -> Void) {
        didSets.append(DidSetObserver(observer: observer, block: observerBlock))
        observerBlock(self.value)
    }
    public func willSet(observer: AnyObject, observerBlock: @escaping (Value, Value) -> Void) {
        willSets.append(WillSetObserver(observer: observer, block: observerBlock))
    }
    
    public func remove(observer: AnyObject) {
        didSets = didSets.filter { $0.observer !== observer }
        willSets = willSets.filter { $0.observer !== observer }
    }
}
