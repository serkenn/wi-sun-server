# Docker 永続データを USB 側で運用する方針

## 結論
SD カード消耗を減らす目的なら、MariaDB や Grafana のバックアップを USB に置くだけでは不十分です。`/var/lib/docker` 配下に置かれる named volume の実体そのものを、USB 側で運用する設計が本命です。

## 理由
このリポジトリの `docker-compose.yml` は balena の named volume を使っています。現在の balenaOS では、これらの実体は通常 `/var/lib/docker` に置かれます。`/var/lib/docker` が SD 上にある限り、DB 更新や Grafana の書き込みは SD を消耗させます。

## 補助サービスの位置づけ
`usb-storage` サービスは次の用途には有効です。
- USB の認識確認
- 自動 mount
- バックアップ保存先
- 移行作業用の一時保存先

ただし、これだけで MariaDB や Grafana の live data が USB に移るわけではありません。

## 目標
- USB ストレージを `ext4` で常設
- balenaOS 再起動後も安定して認識
- Docker 永続データを USB 側で扱う

## 実務上の考え方
- 「USB を mount した」だけでは不十分
- 「実際にどこへ書いているか」を `df -h` と `mount` と `/var/lib/docker` の実体で確認する
- SD 消耗対策の成否は、DB の live write が USB 側へ出ているかで判断する

## このリポジトリでやること
- Compose 側では USB 補助サービスを用意する
- Compose 側では USB バックアップの世代管理も用意する
- README では制約を明記する
- Host 側運用が必要な部分はドキュメントで切り分ける
