//
//  ThemeViewController.swift
//  zhihuDaily 2.0
//
//  Created by Nirvana on 10/15/15.
//  Copyright © 2015 NSNirvana. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON
import SDWebImage

class ThemeViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var navTitleLabel: UILabel!
    
    var id = ""
    var name = ""
    var selectedIndex: [Int] = []
    var navImageView: UIImageView!
    var themeSubview: ParallaxHeaderView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //清空原数据
        self.appCloud().themeContent = nil
        
        //拿到新数据
        refreshData()
        
        //创建leftBarButtonItem
        let leftButton = UIBarButtonItem(image: UIImage(named: "leftArrow"), style: .Plain, target: self.revealViewController(), action: "revealToggle:")
        leftButton.tintColor = UIColor.whiteColor()
        self.navigationItem.setLeftBarButtonItem(leftButton, animated: false)
        
        //为当前view添加手势识别
        self.view.addGestureRecognizer(self.revealViewController().panGestureRecognizer())
        
        //生成并配置HeaderImageView
        navImageView = UIImageView(frame: CGRectMake(0, 0, self.view.frame.width, 64))
        navImageView.contentMode = UIViewContentMode.ScaleAspectFill
        navImageView.clipsToBounds = true
        
        //将其添加到ParallaxView
        themeSubview = ParallaxHeaderView.parallaxThemeHeaderViewWithSubView(navImageView, forSize: CGSizeMake(self.view.frame.width, 64), andImage: navImageView.image) as! ParallaxHeaderView
        themeSubview.delegate = self
        
        //将ParallaxView设置为tableHeaderView，主View添加tableView
        self.tableView.tableHeaderView = themeSubview
        self.view.addSubview(tableView)
        
        //设置NavigationBar为透明
        self.navigationController?.navigationBar.lt_setBackgroundColor(UIColor.clearColor())
        self.navigationController?.navigationBar.shadowImage = UIImage()
        
        //tableView基础设置
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.separatorStyle = .None
        self.tableView.showsVerticalScrollIndicator = false
    }

    func refreshData() {
        //更改标题
        navTitleLabel.text = name
        
        //获取数据
        Alamofire.request(.GET, "http://news-at.zhihu.com/api/4/theme/" + id).responseJSON { (_, _, dataResult) -> Void in
            guard dataResult.error == nil else {
                print("数据获取失败")
                return
            }
            let data = JSON(dataResult.value!)
            
            //取得Story
            let storyData = data["stories"]
            //暂时注入themeStory
            var themeStory: [ContentStoryModel] = []
            for i in 0 ..< storyData.count {
                //判断是否含图
                if storyData[i]["images"] != nil {
                    themeStory.append(ContentStoryModel(images: [storyData[i]["images"][0].string!], id: String(storyData[i]["id"]), title: storyData[i]["title"].string!))
                } else {
                    //若不含图
                    themeStory.append(ContentStoryModel(images: [""], id: String(storyData[i]["id"]), title: storyData[i]["title"].string!))
                }
            }
            
            //取得avatars
            let avatarsData = data["editors"]
            //暂时注入editorsAvatars
            var editorsAvatars: [String] = []
            for i in 0 ..< avatarsData.count {
                editorsAvatars.append(avatarsData[i]["avatar"].string!)
            }
            
            //更新图片
            self.navImageView.sd_setImageWithURL(NSURL(string: data["background"].string!), completed: { (image, _, _, _) -> Void in
                self.themeSubview.blurViewImage = image
                self.themeSubview.refreshBlurViewForNewImage()
            })
            
            //注入themeContent
            self.appCloud().themeContent = ThemeContentModel(stories: themeStory, background: data["background"].string!, editorsAvatars: editorsAvatars)
            
            //刷新数据
            self.tableView.reloadData()
        }
    }

    //设置StatusBar颜色
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .LightContent
    }
    
    //获取总代理
    func appCloud() -> AppDelegate {
        return UIApplication.sharedApplication().delegate as! AppDelegate
    }
}

extension ThemeViewController: UITableViewDelegate, UITableViewDataSource, ParallaxHeaderViewDelegate {
    //实现Parallax效果
    func scrollViewDidScroll(scrollView: UIScrollView) {
        let header = self.tableView.tableHeaderView as! ParallaxHeaderView
        header.layoutThemeHeaderViewForScrollViewOffset(scrollView.contentOffset)
    }
    
    //设置滑动极限
    func lockDirection() {
        self.tableView.contentOffset.y = -95
    }
    
    //处理UITableViewDataSource
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        //如果还未获取到数据
        if appCloud().themeContent == nil {
            return 0
        }
        //如含有数据
        return appCloud().themeContent!.stories.count + 1
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if indexPath.row == 0 {
            let cell = tableView.dequeueReusableCellWithIdentifier("themeEditorTableViewCell") as! ThemeEditorTableViewCell
            for (index, editorsAvatar) in appCloud().themeContent!.editorsAvatars.enumerate() {
                let avatar = UIImageView(frame: CGRectMake(62 + CGFloat(37 * index), 12.5, 20, 20))
                avatar.contentMode = .ScaleAspectFill
                avatar.layer.cornerRadius = 10
                avatar.clipsToBounds = true
                avatar.sd_setImageWithURL(NSURL(string: editorsAvatar))
                cell.contentView.addSubview(avatar)
            }
            return cell
        }
        
        //取到Story数据
        let tempContentStoryItem = appCloud().themeContent!.stories[indexPath.row - 1]
        
        //保证图片一定存在，选择合适的Cell类型
        guard tempContentStoryItem.images[0] != "" else {
            let cell = tableView.dequeueReusableCellWithIdentifier("themeTextTableViewCell") as! ThemeTextTableViewCell
            //验证是否已被点击过
            if let _ = selectedIndex.indexOf(indexPath.row) {
                cell.themeTextLabel.textColor = UIColor.lightGrayColor()
            } else {
                cell.themeTextLabel.textColor = UIColor.blackColor()
            }
            cell.themeTextLabel.text = tempContentStoryItem.title
            return cell
        }

        //处理图片存在的情况
        let cell = tableView.dequeueReusableCellWithIdentifier("themeContentTableViewCell") as! ThemeContentTableViewCell
        //验证是否已被点击过
        if let _ = selectedIndex.indexOf(indexPath.row) {
            cell.themeContentLabel.textColor = UIColor.lightGrayColor()
        } else {
            cell.themeContentLabel.textColor = UIColor.blackColor()
        }
        cell.themeContentLabel.text = tempContentStoryItem.title
        cell.themeContentImageView.sd_setImageWithURL(NSURL(string: tempContentStoryItem.images[0]))

        return cell
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if indexPath.row == 0 {
            return 45
        }
        return 92
    }
    
    //处理UITableViewDelegate
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if indexPath.row == 0 {
            return
        }
        
        selectedIndex.append(indexPath.row)
        if tableView.cellForRowAtIndexPath(indexPath) is ThemeContentTableViewCell {
            (tableView.cellForRowAtIndexPath(indexPath) as! ThemeContentTableViewCell).themeContentLabel.textColor = UIColor.lightGrayColor()
        } else {
            (tableView.cellForRowAtIndexPath(indexPath) as! ThemeTextTableViewCell).themeTextLabel.textColor = UIColor.lightGrayColor()
        }
        
        //拿到webViewController
        let webViewController = self.storyboard?.instantiateViewControllerWithIdentifier("webViewController") as! WebViewController
        webViewController.newsId = appCloud().themeContent!.stories[self.tableView.indexPathForSelectedRow!.row - 1].id
        webViewController.index = indexPath.row - 1
        webViewController.isThemeStory = true

        //实施转场
        self.navigationController?.pushViewController(webViewController, animated: true)
    }
}
