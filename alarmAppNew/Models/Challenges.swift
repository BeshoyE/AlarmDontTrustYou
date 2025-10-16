//
//  Challenges.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/3/25.
//
public enum Challenges: CaseIterable, Codable, Equatable, Hashable {
  case qr
  case stepCount
  case math

  public var displayName: String {
    switch self {
    case .qr: return "QR Code"
    case .stepCount: return "Step Count"
    case .math: return "Math"
    }
  }

  var iconName: String {
    switch self {
    case .qr: return "qrcode"
    case .stepCount: return "figure.walk"
    case .math: return "function"
    }
  }
}
