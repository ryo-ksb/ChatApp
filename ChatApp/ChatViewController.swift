//
//  ChatViewController.swift
//  ChatApp
//
//  Created by 小芝亮太 on 2018/11/04.
//  Copyright © 2018 小芝亮太. All rights reserved.
//

import UIKit
import MessageKit
import Firebase

class ChatViewController: MessagesViewController {
    
    //外部のファイルから書き換えられないようにprivate
    private var ref: DatabaseReference! //RealtimeDatabaseからの応答
    private var user: User! //ユーザー
    private var handle: DatabaseHandle!
    var messageList: [Message] = [] //Message型のオブジェクトの入る配列
    var sendData: [String: Any] = [:] //Realtimeデータベースに書き込む内容を格納する辞書
    let dateFormatter: DateFormatter = DateFormatter() //日時のフォーマットを管理するもの
    var readData: [[String: Any]] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        ref = Database.database().reference() //リファレンスの初期化
        user = Auth.auth().currentUser      //認証した現在のユーザーを格納
        
        //各種デリゲートをこのVCに設定
        messagesCollectionView.messagesDataSource = self as MessagesDataSource
        messagesCollectionView.messagesLayoutDelegate = self as MessagesLayoutDelegate
        messagesCollectionView.messagesDisplayDelegate = self as MessagesDisplayDelegate
        messagesCollectionView.messageCellDelegate = self as MessageCellDelegate
        messageInputBar.delegate = self as MessageInputBarDelegate
        
        // メッセージ入力時に一番下までスクロール
        scrollsToBottomOnKeybordBeginsEditing = true // default false
        maintainPositionOnKeyboardFrameChanged = true // default false
        
        dateFormatter.dateStyle = .medium //日付の表示スタイルを決定
        dateFormatter.timeStyle = .short  //時刻の表示スタイルを決定
        dateFormatter.locale = Locale(identifier: "ja_JP") //地域を決定
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        updateViewWhenMessageAdded() //画面が表示される直前に実行
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        ref.child("chats").removeObserver(withHandle: handle)
    }
    
    //Firebaseにチャット内容を保存するためのメソッド
    func sendMessageToFirebase(text: String){
        if !sendData.isEmpty {sendData = [:] }          //辞書の初期化
        sendData = [ "senderName": user?.displayName,   //送信者の名前
            "senderID": user?.uid,             //送信者のID
            "content": text,                   //送信内容（今回は文字のみ）
            "createdAt": dateFormatter.string(from: Date()) //送信時刻
        ]
        ref.child("chats").childByAutoId().setValue(sendData) //ここで実際にデータベースに書き込んでいます
        
    }
    
    //メッセージが追加された際に読み込んで画面を更新するメソッド
    func updateViewWhenMessageAdded() {
        
        //handle = でDatabaseHandleを取得
        handle = ref.child("chats").queryLimited(toLast: 25).queryOrdered(byChild: "createdAt").observe(.value) { (snapshot: DataSnapshot) in
            DispatchQueue.main.async { //クロージャの中を同期処理
                self.snapshotToArray(snapshot: snapshot) //スナップショットを配列(readData)に入れる処理。下に定義
                self.displayMessage() //メッセージを画面に表示するための処理
                print("readData: \(self.readData)")
            }
        }
    }
    
    //データベースから読み込んだデータを配列(readData)に格納するメソッド
    func snapshotToArray(snapshot: DataSnapshot){
        if !readData.isEmpty {readData = [] }
        if snapshot.children.allObjects as? [DataSnapshot] != nil  {
            let snapChildren = snapshot.children.allObjects as? [DataSnapshot]
            for snapChild in snapChildren! {
                if let postDict = snapChild.value as? [String: Any] {
                    self.readData.append(postDict)
                }
            }
        }
    }
    
    //メッセージの画面表示に関するメソッド
    func displayMessage() {
        if !messageList.isEmpty {messageList = []}
        for item in readData {
            print("item: \(item)\n")
            let message = Message(sender: Sender(id: item["senderID"] as! String,
                                                 displayName: item["senderName"] as! String),
                                  sentDate: self.dateFormatter.date(from: item["createdAt"] as! String)!,
                                  messageId: UUID().uuidString,
                                  kind: MessageKind.text(item["content"] as! String)
            )
            messageList.append(message)
        }
        messagesCollectionView.reloadData()
        messagesCollectionView.scrollToBottom()
    }

}

extension ChatViewController: MessagesDataSource {
    //自分の情報を設定
    func currentSender() -> Sender {
        return Sender(id: user.uid, displayName: user.displayName!)
    }
    //表示するメッセージの数
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return messageList.count
    }
    //メッセージの実態
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return messageList[indexPath.section] as MessageType
    }
    
    //セルの上の文字
    func cellTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        if indexPath.section % 3 == 0 {
            return NSAttributedString(
                string: MessageKitDateFormatter.shared.string(from: message.sentDate),
                attributes: [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 10),
                             NSAttributedString.Key.foregroundColor: UIColor.darkGray]
            )
        }
        return nil
    }
    
    // メッセージの上の文字
    func messageTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        let name = message.sender.displayName
        return NSAttributedString(string: name, attributes: [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .caption1)])
    }
    
    // メッセージの下の文字
    func messageBottomLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        let dateString = formatter.string(from: message.sentDate)
        return NSAttributedString(string: dateString, attributes: [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .caption2)])
    }
}

// メッセージの見た目に関するdelegate
extension ChatViewController: MessagesDisplayDelegate {
    
    // メッセージの色を変更
    func textColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        return isFromCurrentSender(message: message) ? .white : .darkText
    }
    
    // メッセージの背景色を変更している
    func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        return isFromCurrentSender(message: message) ?
            UIColor(red: 69/255, green: 193/255, blue: 89/255, alpha: 1) :
            UIColor(red: 230/255, green: 230/255, blue: 230/255, alpha: 1)
    }
    
    // メッセージの枠にしっぽを付ける
    func messageStyle(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageStyle {
        let corner: MessageStyle.TailCorner = isFromCurrentSender(message: message) ? .bottomRight : .bottomLeft
        return .bubbleTail(corner, .curved)
    }
    
    // アイコンをセット
    func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        // message.sender.displayNameとかで送信者の名前を取得できるので
        // そこからイニシャルを生成するとよい
        let avatar = Avatar(initials: message.sender.displayName)
        avatarView.set(avatar: avatar)
    }
}

// 各ラベルの高さを設定（デフォルト0なので必須）、メッセージの表示位置に関するデリゲート
extension ChatViewController: MessagesLayoutDelegate {
    
    //cellTopLabelAttributedTextを表示する高さ
    func cellTopLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        if indexPath.section % 3 == 0 { return 10 }
        return 0
    }
    
    //messageTopLabelAttributedTextを表示する高さ
    func messageTopLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        return 16
    }
    
    //messageBottomLabelAttributedTextを表示する高さ
    func messageBottomLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        return 16
    }
}

extension ChatViewController: MessageCellDelegate {
    // メッセージをタップした時の挙動
    func didTapMessage(in cell: MessageCollectionViewCell) {
        print("Message tapped")
    }
}

extension ChatViewController: MessageInputBarDelegate {
    // メッセージ送信ボタンを押されたとき
    func messageInputBar(_ inputBar: MessageInputBar, didPressSendButtonWith text: String) {
        let attributedText = NSAttributedString(string: text, attributes: [.font: UIFont.systemFont(ofSize: 15), .foregroundColor: UIColor.white])
        sendMessageToFirebase(text: text)
        inputBar.inputTextView.text = ""
        messagesCollectionView.scrollToBottom()
    }
}

