# Refreshable

> 在app的开发中，出现最多的一个情况就是显示一个列表来展示数据，就像刷微博一样，要能够上拉加载更多，下拉进行刷新。但在实际开发过程中，需要考虑的情况会更多。我们使用`header`来表示下拉刷新控件，使用`footer`来表示上拉加载控件。

## 在不考虑缓存的情况下单数据源tableView需要考虑以下注意点
1. 首次进入这个页面，没有数据需要进行首次数据加载
2. 首次加载过程中不能显示footer
3. 下拉刷新需要用返回的结果覆盖数据源的数据
4. 下拉刷新后需要还原footer的状态(变更为可以加载更多)
5. 上拉加载成功后需要根据返回数据数量来判断是否还有更多数据，没有更多数据需要修改footer的状态为`没有更多数据了`，并禁止上拉刷新功能。
6. 首次加载数据如果没有网络连接或者加载失败，需要显示一个失败页面，点击失败页面能够重新进行网络请求获取数据。
7. 每次进行下拉刷新都需要将当前page设为`1`
8. 每次进行上拉加载前都需要将当前page进行`+1`操作
9. 每次上拉加载失败都需要将当前page进行`-1`操作，以还原防止，下次上拉加载page多加了的问题

## 如果是多数据源的tableView则需要考虑的更多
1. 首先就是不同数据源的page记录，每个数据源都需要对应一个自己的page
2. 每个数据源都需要记录是否还有更多数据可供加载
3. 甚至每个数据源拥有各自的没数据的文字提示
4. 实际项目中，为了一些效果，还需要记录当前数据源是否处于加载数据状态，以此来显示某些加载页面。
5. 可能还会有一个个性化的定制需求

> 综上所述，仅仅是一个控制器的数据加载逻辑就有这么多，如果有很多这样类似的页面，每次都要考虑这么多问题，难免会有不少疏忽，而且要实现这些功能会产生大量的重复代码，这肯定是我们不希望看到的。

分析上述需求我们发现，实际上通常我们所接触的`tableView`大体上也就需要注意这么多问题，而且为了整个工程的统一性，一般情况所有的处理也是采用同一套逻辑，因此我们完全可以把这些逻辑统一起来，使用一个`Protocol`来实现这些逻辑。得益于Swift强大的`Protocol Extention` 大部分情况我们只需要在合适的关键点调用几个方法就可以了，所有的逻辑默认都已经实现了。`Controller`中的代码更少了，不相关的逻辑都封装好了，逻辑更加简洁了。

## 控制器使用代码

```Swift
class PYMyOrderListController: PYBaseViewController, Refreshable {
    internal var refreshStatus: [(page: Int, isLoading: Bool, noMoreData: Bool, noMoreTitle: String)] = [(1,false,false,"没有更多订单了")]     // 定义每个数据源需要的四个属性，分别是当前页码，是否被正在加载中，是否没有更多数据可供加载了。没有数据可供加载的footer文字
    internal var currentIndex = 0       // 当前现实的数据源索引
    internal var refreshTable: UITableView = UITableView()      // 当前tableView
   
    override func viewDidLoad() {
         view.addSubview(tableView)
         tableView.snp_makeConstraints { (make) in
                     make.left.right.bottom.equalTo(0)
                     make.top.equalTo(segementView.snp_bottom)
             }
         refreshTable = tableView       // 赋值当前tableView
         setupRefreshHeader()           //初始化下拉刷新控件
         setupRefreshFooter()           // 初始化上拉加载控件
     }    
        ///  加载数据的方法
        ///
        ///  - parameter isRefresh: 是否是下拉刷新
    func refreshData(isRefresh: Bool) {    
        refreshStatus[currentIndex].isLoading = true        // 修改当前数据源的加载状态为正在加载
        let indexItem = currentIndex
        let url = URL_OrderList + "/\(type)/\(PageCount)" + "/\(refreshStatus[currentIndex].page).json"
        let request = PYNetWorkTools.GET(url, hudType: .None, failer: { [weak self] (failerTuples) in
            guard self != nil else{ return }
            self?.loadFailer(failerTuples)      // 加载失败的方法
        }) {[weak self] (response, jsonResult) in
            guard self != nil else{ return }
            self?.tableView.hiddenNoNetPlace()
            let array = PYOrderListModel.modelArray(jsonResult)
            if isRefresh {
                self?.totalArray[indexItem] = array
            } else {
                self?.totalArray[indexItem] += array
            }
            self?.loadSuccess(array.count < PageCount)      // 加载成功的方法，并传递一个是否还有更多数据的返回值
        }
        if request != nil {
            requests.append(request!)
        }
    }
}    
```

以上这些代码就可以实现上述所有的功能，怎么样，是不是很有魅力呢？实例中使用了`Refreshable`协议，这套协议可以用在`UIViewController`和`UITableViewController`中，其中的`refreshTable`就是为了适配`UIViewController`所增加的一个属性，否则连这个属性都不用写了。

## 代码中能看到的协议中定义的内容如下
- 属性
    - refreshStatus
    - currentInidex
    - refreshTable

- 方法
    - refreshData(isRefresh: Bool)
    - setupRefreshHeader()
    - setupRefreshFooter()
    - loadFailer(failerTuples: FailerTuples)
    - loadSuccess(noMoreData: Bool?)

## 让我们先看看`Refreshable`这个协议里是怎么写的

```Swift
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
```
整个协议简洁明了，没有一句废话。就把众多需要的功能及注意点都涵盖了。该协议具有以下特点。

- 支持`UITableViewController`以及`UIViewcontroller`的刷新处理。
- 支持多数据源的切换加载。

这两个特性已经涵盖了日常开发中常见的所有情况。当然你也可以只添加上拉加载，不添加下拉刷新功能，总之，这些都随便。

