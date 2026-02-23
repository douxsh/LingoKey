# LingoKey

多言語対応のiOSカスタムキーボード。日本語入力から英語・韓国語への翻訳、韓国語・英語の入力補正をキーボード上で完結できます。

## 機能

- **日本語 → 英語翻訳 (J>E)**: フリック / ローマ字で日本語を入力し、かな漢字変換後に英語へ翻訳
- **日本語 → 韓国語翻訳 (J>K)**: 同様に日本語から韓国語へ翻訳
- **英語入力補正 (EN)**: QWERTYキーボードで英文入力、スペルや文法の補正候補を表示
- **韓国語入力補正 (KR)**: 2ボル式ハングルキーボードで韓国語入力、補正候補を表示

### 日本語入力

- **フリック入力**: iOS標準に近いフリックキーボード（濁点・半濁点・小文字切替対応）
- **ローマ字入力**: QWERTYキーボードからローマ字でひらがな変換
- **かな漢字変換**: [AzooKeyKanaKanjiConverter](https://github.com/azooKey/AzooKeyKanaKanjiConverter) によるローカル変換（オフライン動作）
- **2段階確定**: ひらがな → 漢字/カタカナ確定 → 翻訳の2ステップフロー

### その他

- 数字・記号キーボード（2ページ）
- 絵文字ピッカー
- ダークモード / ライトモード対応（Apple純正キーボードに準拠した配色）

## 技術スタック

| 項目 | 詳細 |
|------|------|
| 言語 | Swift 5.9 |
| UI | SwiftUI |
| 最小対応OS | iOS 17.0 |
| キーボード基盤 | [KeyboardKit](https://github.com/KeyboardKit/KeyboardKit) 9.0+ |
| かな漢字変換 | [AzooKeyKanaKanjiConverter](https://github.com/azooKey/AzooKeyKanaKanjiConverter) 0.8+ |
| 翻訳・補正API | Claude API (Anthropic) |
| プロジェクト生成 | [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`project.yml`) |

## セットアップ

### 前提条件

- Xcode 15.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)（`project.yml` からプロジェクトを生成する場合）
- Claude API キー（翻訳・補正機能に必要）

### ビルド手順

```bash
# リポジトリをクローン
git clone https://github.com/douxsh/LingoKey.git
cd LingoKey

# XcodeGenでプロジェクト生成（任意、.xcodeproj同梱済み）
xcodegen generate

# Xcodeで開く
open LingoKey.xcodeproj
```

1. Xcodeでビルドターゲット「LingoKey」を選択し、実機またはシミュレータでビルド
2. **設定 → 一般 → キーボード → キーボード → 新しいキーボードを追加** から「LingoKey」を有効化
3. アプリを起動し、Claude APIキーを設定

## プロジェクト構成

```
├── LingoKey/                 # ホストアプリ
│   ├── App/                  # App entry point
│   └── Views/                # 設定画面、オンボーディング
├── LingoKeyboard/            # キーボードExtension
│   ├── InputEngine/          # ローマ字変換、ハングル合成、フリック入力マップ
│   ├── Models/               # データモデル (Suggestion, API models)
│   ├── Services/             # Claude API、かな漢字変換、サジェスト管理
│   └── Views/                # キーボードUI (QWERTY, フリック, ハングル, 絵文字等)
├── Shared/                   # アプリ・Extension共有コード
│   ├── KeyboardMode.swift    # 入力モード定義
│   └── SharedSettings.swift  # App Group経由の設定共有
└── project.yml               # XcodeGen定義
```

## ライセンス

MIT
