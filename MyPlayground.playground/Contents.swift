//: Playground - noun: a place where people can play

import RxCocoa
import RxSwift
import PlaygroundSupport


let f = DateFormatter()
f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
f.date(from: "2017-10-25T08:01:26Z")
