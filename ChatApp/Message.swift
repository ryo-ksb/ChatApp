//
//  Message.swift
//  ChatApp
//
//  Created by 小芝亮太 on 2018/11/04.
//  Copyright © 2018 小芝亮太. All rights reserved.
//

import Foundation
import MessageKit

struct Message: MessageType { //classではなくstruct!
    var sender: Sender
    var sentDate: Date
    var messageId: String
    var kind: MessageKind
}
