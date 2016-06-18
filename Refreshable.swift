//
//  Refreshable.swift
//  pyjia
//
//  Created by GeekerHua on 16/6/16.
//  Copyright © 2016年 ilegong. All rights reserved.
//

import UIKit

///  刷新协议
protocol Refreshable {
    ///  刷新数据的方法，必须实现，调用这个方法来执行下拉刷新和上拉加载
    ///
    ///  - parameter isRefresh: 是否是下拉刷新
    func refreshData(isRefresh: Bool)
    
    /// 刷新状态的四个参数，分别是，当前页码，是否正在加载中，是否没有更多数据了，没有更多数据的footer显示文字
    var refreshStatus: [(page: Int, isLoading: Bool, noMoreData: Bool, noMoreTitle: String)] {set get}
    
    /// 当前数据源的索引号
    var currentIndex: Int {set get}
    
    /// 需要处理的tableView
    var refreshTable: UITableView {get set}
}

// MARK: - 遵守这个协议的是控制器
extension Refreshable where Self: UIViewController {

    ///  加载数据失败调用此方法
    ///
    ///  - parameter failerTuples: 失败原因
    mutating func loadFailer(failerTuples: (type: NetFailerType, desc: String?)?) {
        refreshStatus[currentIndex].page -= 1
        if refreshStatus[currentIndex].page < 0 {
            refreshStatus[currentIndex].page = 0
        }
        refreshStatus[currentIndex].isLoading = false
        refreshFooter()
        if refreshTable.mj_header != nil {
            refreshTable.mj_header.endRefreshing()
        }
        
        if failerTuples?.type == NetFailerType.NoNet {
            if refreshTable.visibleCells.isEmpty {
                refreshTable.showNoNetPlace({ [weak self] in
                    guard self != nil else { return }
                    self?.refreshData(true)
                    })
            } else {
                showToast(failerTuples?.type.rawValue ?? "")
            }
        }
        refreshTable.reloadData()
    }
    
    ///  加载数据成功调用此方法
    ///
    ///  - parameter noMoreData: 是否没有更多数据了
    mutating func loadSuccess(noMoreData: Bool?) {
        refreshStatus[currentIndex].isLoading = false
        if let noMoreData = noMoreData where refreshTable.mj_footer != nil {
            refreshStatus[currentIndex].noMoreData = noMoreData
            refreshTable.mj_footer.hidden = false
            refreshFooter()
        }
        if refreshTable.mj_header != nil {
            refreshTable.mj_header.endRefreshing()
        }
        refreshTable.reloadData()
    }
    
    ///  初始化下拉刷新控件
    func setupRefreshHeader() {
        let header = MJRefreshNormalHeader {[weak self] () -> Void in
            guard self != nil else { return }
            self?.refreshTable.mj_footer.resetNoMoreData()
            self?.refreshStatus[self!.currentIndex].page = 1
            self?.refreshData(true)
            self?.refreshStatus[self!.currentIndex].isLoading = true
        }
        refreshTable.mj_header = header
    }
    
    ///  初始化上拉加载控件
    func setupRefreshFooter() {
        let footer = MJRefreshBackStateFooter {[weak self] () -> Void in
            guard self != nil else { return }
            self?.refreshStatus[self!.currentIndex].page += 1
            self?.refreshData(false)
            self?.refreshStatus[self!.currentIndex].isLoading = true
        }
        footer.hidden = true
        refreshTable.mj_footer = footer
    }
    
    ///  刷新上拉加载控件，用来重置上拉刷新控件状态，控制能够刷新以及显示类型
    func refreshFooter() {
        if refreshTable.mj_footer != nil {
            if refreshStatus[currentIndex].noMoreData {
                refreshTable.mj_footer.endRefreshingWithNoMoreData()
            } else {
                refreshTable.mj_footer.endRefreshing()
            }
        }
    }
}
