# USB ストレージ運用メモ

## 方針
このリポジトリでは、MariaDB や Grafana の永続データを SD カードではなく USB ストレージ側へ置くことを推奨します。目的は Raspberry Pi 4B の SD 消耗を減らすことです。

## 注意
balena のマルチコンテナでは `docker-compose.yml` の `volumes` に任意の bind mount を自由に書けません。named volume は使えますが、ホスト上の USB パスをそのまま指定する方式は制約があります。

そのため、アプリの Compose だけで吸収するのではなく、balenaOS 側で永続データの保存先を外部ストレージへ寄せる運用を前提にしてください。

## 推奨前提
- USB ストレージは常設接続にする
- ファイルシステムは `ext4` を使う
- 起動時に安定して認識できるよう、UUID または LABEL で管理する

## 確認項目
- `lsblk -f` で USB デバイス名、UUID、LABEL、ファイルシステムを確認する
- balenaOS 側で再起動後も同じストレージを認識できることを確認する
- MariaDB と Grafana のデータ量に対して十分な容量があることを確認する

## 運用メモ
- SD 消耗を避けたい場合、最優先で見直すべきなのは DB とログ保存先です。
- このリポジトリの Compose は balena の named volume を使っています。実データの配置先は Host 側運用と合わせて設計してください。
