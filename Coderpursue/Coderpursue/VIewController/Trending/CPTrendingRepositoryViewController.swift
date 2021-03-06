//
//  CPRepositoryViewController.swift
//  Coderpursue
//
//  Created by WengHengcong on 3/9/16.
//  Copyright © 2016 JungleSong. All rights reserved.
//

import UIKit
import Moya
import Foundation
import MJRefresh
import ObjectMapper
import Kingfisher

public enum CPReposActionType:String {
    case Watch = "watch"
    case Star = "star"
    case Fork = "fork"
}

class CPTrendingRepositoryViewController: CPBaseViewController {

    @IBOutlet weak var reposPoseterV: CPReposPosterView!
    
    @IBOutlet weak var reposInfoV: CPReposInfoView!
    
    @IBOutlet weak var tableView: UITableView!
    
    var repos:ObjRepos?
    var reposInfoArr = [[String:String]]()
    var reposShareImage:UIImage?
    
    var user:ObjUser?
    var hasWatchedRepos:Bool = false
    var hasStaredRepos:Bool = false
    
    var actionType:CPReposActionType = .Watch
    
    // 顶部刷新
    let header = MJRefreshNormalHeader()
    
    // MARK: - view cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        rvc_customView()
        rvc_userIsLogin()
        rvc_setupTableView()
        rvc_loadAllRequset()
        self.title = repos!.name!
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

    }
    
    // MARK: - view
    
    func rvc_customView(){
        
        self.rightItemImage = UIImage(named: "nav_share_35")
        self.rightItemSelImage = UIImage(named: "nav_share_35")
        self.rightItem?.isHidden = false
        
        self.navigationController?.setNavigationBarHidden(false, animated: false)
        self.view.backgroundColor = UIColor.white
        
    }
    
    func rvc_setupTableView() {
        
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.separatorStyle = .none
        self.tableView.backgroundColor = UIColor.viewBackgroundColor()
        self.automaticallyAdjustsScrollViewInsets = false
        header.setTitle("Pull down to refresh", for: .idle)
        header.setTitle("Release to refresh", for: .pulling)
        header.setTitle("Loading ...", for: .refreshing)
        header.setRefreshingTarget(self, refreshingAction: #selector(CPTrendingRepositoryViewController.headerRefresh))
        // 现在的版本要用mj_header
//        self.tableView.mj_header = header
    }
    
    // MARK: - action
    
    func headerRefresh(){
        print("下拉刷新")
        
    }
    
    func rvc_updateViewContent() {
        
        let objRepo = repos!
        reposPoseterV.repo = objRepo
        reposPoseterV.watched = hasWatchedRepos
        reposPoseterV.stared = hasStaredRepos
        
        reposInfoV.repo = objRepo
        
       prefectchShareImage(){
            
        }
    }
    
    func prefectchShareImage( _ completionHandler: @escaping ()-> Void ){
        
        if let urlStr = repos?.owner?.avatar_url {
            let url:URL = URL.init(string: urlStr)!
            let downloader = KingfisherManager.shared.downloader
            
            downloader.downloadImage(with: url, options: nil, progressBlock: { (receivedSize, totalSize) in
                
                }, completionHandler: { (image, error, imageURL, originalData) in
                    self.reposShareImage = image
                    completionHandler()
            })
            
        }

    }
    
    
    func rvc_userIsLogin() {
        
        user = UserInfoHelper.sharedInstance.user
        
        reposPoseterV.reposActionDelegate = self
        
        let uname = repos!.owner!.login!
        let ownerDic:[String:String] = ["img":"octicon_person_25","desc":uname,"discolsure":"true"]
        reposInfoArr.append(ownerDic)
        
    }
    
    func rvc_loadAllRequset(){
        rvc_getReopsRequest()
        rvc_checkWatchedRequset()
        rvc_checkStarredRqeuset()
    }
    
    
    override func leftItemAction(_ sender: UIButton?) {
        self.navigationController?.popViewController(animated: true)
    }
    
    override func rightItemAction(_ sender: UIButton?) {
        
        let shareContent:ShareContent = ShareContent()
        shareContent.shareTitle = repos?.name
        if let repoDescription = repos?.cdescription {
            shareContent.shareContent = "Code Repository \((repos?.name)!) : \(repoDescription)"
        }else{
            shareContent.shareContent = "Code Repository \((repos?.name)!)"
        }
        shareContent.shareUrl = repos?.html_url
        
        if reposShareImage == nil {
            MBProgressHUD.showAdded(to: self.view, animated: true)
            prefectchShareImage({
                MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
                shareContent.shareImage = self.reposShareImage
                ShareHelper.sharedInstance.shareContentInView(self, content: shareContent, soucre: ShareSource.Repository)
            })
        }else{
            shareContent.shareImage = self.reposShareImage
            ShareHelper.sharedInstance.shareContentInView(self, content: shareContent, soucre: ShareSource.Repository)
        }
        
    }
    
    // MARK: - request
    
    func rvc_getReopsRequest(){
        
        MBProgressHUD.showAdded(to: self.view, animated: true)
        
        let owner = repos!.owner!.login!
        let repoName = repos!.name!
        
        Provider.sharedProvider.request(.userSomeRepo(owner:owner,repo:repoName) ) { (result) -> () in
            
            var message = "No data to show"
            
            MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
            
            switch result {
            case let .success(response):
                
                do {
                    if let result:ObjRepos = Mapper<ObjRepos>().map(JSONObject: try response.mapJSON() ) {
                        self.repos = result
                        self.rvc_updateViewContent()

                    } else {

                    }
                } catch {

                    CPGlobalHelper.sharedInstance.showError(message, view: self.view)
                }
            case let .failure(error):
                guard let error = error as? CustomStringConvertible else {
                    break
                }
                message = error.description

                CPGlobalHelper.sharedInstance.showError(message, view: self.view)
                
            }
        }

        
    }
    
    func rvc_checkWatchedRequset() {
        
        if (!UserInfoHelper.sharedInstance.isLogin){
            return
        }
        
        let owner = repos!.owner!.login!
        let repoName = repos!.name!
        
        Provider.sharedProvider.request(.checkWatched(owner:owner,repo:repoName) ) { (result) -> () in
            
            var message = "No data to show"
            
            MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
            switch result {
            case let .success(response):
                
                let statusCode = response.statusCode
                if(statusCode == CPHttpStatusCode.ok.rawValue){
                    self.hasWatchedRepos = true
                }else{
                    self.hasWatchedRepos = false
                }
                self.rvc_updateViewContent()
                
            case let .failure(error):
                guard let error = error as? CustomStringConvertible else {
                    break
                }
                message = error.description
                CPGlobalHelper.sharedInstance.showError(message, view: self.view)
                
            }
        }

    }
    
    func rvc_checkStarredRqeuset() {
        
        if (!UserInfoHelper.sharedInstance.isLogin){
            return
        }
        
        let owner = repos!.owner!.login!
        let repoName = repos!.name!
        
        Provider.sharedProvider.request(.checkStarred(owner:owner,repo:repoName) ) { (result) -> () in
            
            var message = "No data to show"
            
            MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
            print(result)
            switch result {
            case let .success(response):
                
                let statusCode = response.statusCode
                if(statusCode == CPHttpStatusCode.noContent.rawValue){
                    self.hasStaredRepos = true
                }else{
                    self.hasStaredRepos = false
                }
                self.rvc_updateViewContent()
                
            case let .failure(error):
                guard let error = error as? CustomStringConvertible else {
                    break
                }
                message = error.description
                CPGlobalHelper.sharedInstance.showError(message, view: self.view)
                
            }
        }
        
    }

    func rvc_watchRequest() {
        
        let owner = repos!.owner!.login!
        let repoName = repos!.name!
        Provider.sharedProvider.request(.watchingRepo(owner:owner,repo:repoName,subscribed:"true",ignored:"false") ) { (result) -> () in
            
            var message = "No data to show"
            
            MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
            print(result)
            switch result {
            case let .success(response):
                
                let statusCode = response.statusCode
                if(statusCode == CPHttpStatusCode.noContent.rawValue){
                    self.hasWatchedRepos = true
                    CPGlobalHelper.sharedInstance.showError("Watch Successsful", view: self.view)
                    self.rvc_updateViewContent()
                }else{
                    
                }
                
            case let .failure(error):
                guard let error = error as? CustomStringConvertible else {
                    break
                }
                message = error.description
                CPGlobalHelper.sharedInstance.showError(message, view: self.view)
                
            }
        }
        
    }
    
    func rvc_unwatchRequest() {
        let owner = repos!.owner!.login!
        let repoName = repos!.name!
        
        Provider.sharedProvider.request(.unWatchingRepo(owner:owner,repo:repoName) ) { (result) -> () in
            
            var message = "No data to show"
            
            MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
            print(result)
            switch result {
            case let .success(response):
                
                let statusCode = response.statusCode
                if(statusCode == CPHttpStatusCode.noContent.rawValue){
                    self.hasWatchedRepos = false
                    CPGlobalHelper.sharedInstance.showError("Unwatch Successsful", view: self.view)
                    self.rvc_updateViewContent()

                }else{
                    
                }
                
            case let .failure(error):
                guard let error = error as? CustomStringConvertible else {
                    break
                }
                message = error.description
                CPGlobalHelper.sharedInstance.showError(message, view: self.view)
                
            }
        }
        
    }
    
    func rvc_starRequest() {
        let owner = repos!.owner!.login!
        let repoName = repos!.name!
        
        Provider.sharedProvider.request(.starRepo(owner:owner,repo:repoName) ) { (result) -> () in
            
            var message = "No data to show"
            
            MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
            print(result)
            switch result {
            case let .success(response):
                
                let statusCode = response.statusCode
                if(statusCode == CPHttpStatusCode.noContent.rawValue){
                    self.hasStaredRepos = true
                    CPGlobalHelper.sharedInstance.showError("Star Successsful", view: self.view)
                    self.rvc_updateViewContent()
                }else{
                    
                }
                
            case let .failure(error):
                guard let error = error as? CustomStringConvertible else {
                    break
                }
                message = error.description
                CPGlobalHelper.sharedInstance.showError(message, view: self.view)
                
            }
        }
        
    }
    
    func rvc_unstarRequest() {
        let owner = repos!.owner!.login!
        let repoName = repos!.name!
        
        Provider.sharedProvider.request(.unstarRepo(owner:owner,repo:repoName) ) { (result) -> () in
            
            var message = "No data to show"
            
            MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
            print(result)
            switch result {
            case let .success(response):
                
                let statusCode = response.statusCode
                if(statusCode == CPHttpStatusCode.noContent.rawValue){
                    self.hasStaredRepos = false
                    CPGlobalHelper.sharedInstance.showError("Unstar this repository successsful!", view: self.view)
                    self.rvc_updateViewContent()

                }else{
                    
                }
                
            case let .failure(error):
                guard let error = error as? CustomStringConvertible else {
                    break
                }
                message = error.description
                CPGlobalHelper.sharedInstance.showError(message, view: self.view)
                
            }
        }
        
    }
    
    func rvc_forkRequest() {
        let owner = repos!.owner!.login!
        let repoName = repos!.name!
        
        Provider.sharedProvider.request(.createFork(owner:owner,repo:repoName) ) { (result) -> () in
            
            var message = "No data to show"
            
            MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
            print(result)
            switch result {
            case let .success(response):
                
                let statusCode = response.statusCode
                if(statusCode == CPHttpStatusCode.accepted.rawValue){
                    CPGlobalHelper.sharedInstance.showError("Fork this repository successsful!", view: self.view)
                }else{
                }
                
            case let .failure(error):
                guard let error = error as? CustomStringConvertible else {
                    break
                }
                message = error.description
                CPGlobalHelper.sharedInstance.showError(message, view: self.view)
                
            }
        }
        
    }

}


extension CPTrendingRepositoryViewController : UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let row = (indexPath as NSIndexPath).row
        let cellId = "CPDevUserInfoCellIdentifier"

        var cell = tableView .dequeueReusableCell(withIdentifier: cellId) as? CPDevUserInfoCell
        if cell == nil {
            cell = (CPDevUserInfoCell.cellFromNibNamed("CPDevUserInfoCell") as! CPDevUserInfoCell)
        }
        
        //handle line in cell
        if row == 1 {
            cell!.topline = true
        }
        
        if (row == reposInfoArr.count-1) {
            cell!.fullline = true
        }else {
            cell!.fullline = false
        }
        cell!.duic_fillData(reposInfoArr[row])
        cell!.backgroundColor = UIColor.hexStr("#e8e8e8", alpha: 1.0)
        
        return cell!;
        
    }
    
}
extension CPTrendingRepositoryViewController : UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        return 44
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        self.tableView.deselectRow(at: indexPath, animated: true)
        let user = self.repos!.owner!
        self.performSegue(withIdentifier: SegueRepositoryToOwner, sender: user)
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {

        if(segue.identifier == SegueRepositoryToOwner) {
            let devVC = segue.destination as! CPTrendingDeveloperViewController
            devVC.hidesBottomBarWhenPushed = true
            
            let user = sender as? ObjUser
            if(user != nil){
                devVC.developer = user
            }
        }

    }
    
}

extension CPTrendingRepositoryViewController:ReposActionProtocol {
    
    
    func watchReposAction() {
        actionType = .Watch
        showAlertView()
    }
    
    func starReposAction() {
        actionType = .Star
        showAlertView()
    }
    
    func forkReposAction() {
        actionType = .Fork
        showAlertView()
    }
    
    
    func showAlertView() {
        
        var title = ""
        var message = ""
//        var clickSure: ((UIAlertAction) -> Void) = {
//            (UIAlertAction)->Void in
//        }
        switch(actionType){
        case .Watch:
            if(hasWatchedRepos){
                title = "Unwatching..."
                message = ""
            }else{
                title = "Watching..."
                message = "Watching a Repository registers the user to receive notifications on new discussions."
            }

        case .Star:
            if(hasStaredRepos){
                title = "Unstarring..."
                message = ""
            }else{
                title = "Starring..."
                message = "Repository Starring is a feature that lets users bookmark repositories."
            }

        case .Fork:
            title = "Forking..."
            message = "A fork is a copy of a repository."
        }
        
        let alertController = UIAlertController(title: title, message:message, preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (action) in
            // ...
        }
        alertController.addAction(cancelAction)
        
        let OKAction = UIAlertAction(title: "Sure", style: .default) { (action) in
            
            switch(self.actionType){
            case .Watch:
                if(self.hasWatchedRepos){
                    self.rvc_unwatchRequest()
                }else{
                    self.rvc_watchRequest()
                }
                
            case .Star:
                if(self.hasStaredRepos){
                    self.rvc_unstarRequest()
                }else{
                    self.rvc_starRequest()
                }
                
            case .Fork:
                self.rvc_forkRequest()
            }
            
            self.rvc_updateViewContent()

        }
        alertController.addAction(OKAction)
        
        self.present(alertController, animated: true) {
            // ...
        }
        
    }
    
        
}

