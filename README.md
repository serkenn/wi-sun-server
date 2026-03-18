# Wi-SUN 監視基盤 for Raspberry Pi 4B

## 概要
このリポジトリは、`docs/system.md` にある構成のうち Raspberry Pi 4B 側を balenaCloud で運用するためのマルチコンテナ定義です。Pi 4B 上で `MariaDB`、`Zabbix Server`、`Zabbix Web`、`Grafana` を動かし、Pi 3 側から送られてくる監視データを保存・可視化します。

対象 fleet は `Pi-Smarthome`、デバイスタイプは balenaCloud 上の `Raspberry Pi 4 (using 64bit OS)` を前提とします。

## 構成
- `docker-compose.yml`: balenaCloud 用のマルチコンテナ定義
- `.env.template`: ローカル開発や設定確認用の環境変数雛形
- `.github/workflows/balena-deploy.yml`: GitHub Actions からの自動デプロイ設定
- `docs/system.md`: システム全体構成図
- `docs/usb-storage.md`: USB ストレージ運用メモ
- `docs/balena-usb-setup.md`: balenaOS 実機での USB ストレージ確認手順
- `usb-storage/`: USB 自動 mount 用の補助サービス
- `AGENTS.md`: 開発者・エージェント向け運用ガイド

公開ポートの初期値は以下です。
- `3000`: Grafana
- `8080`: Zabbix Web
- `10051`: Zabbix Server

`docker-compose.yml` には `cloudflared` も含めています。`CF_TUNNEL_TOKEN` を設定すると、Grafana や Zabbix Web を Cloudflare Tunnel 経由で公開できます。
また、`usb-storage` サービスは `LABEL=PI4DATA` の USB を検出してコンテナ内 `/mnt/usb` に自動 mountしますが、これは補助用途です。SD 消耗対策の本命は Docker 永続データ全体を USB 側で運用することです。

## Balena Cloud への手動デプロイ
前提:
- balenaCloud に fleet `Pi-Smarthome` を作成済みであること
- device type は `Raspberry Pi 4 (using 64bit OS)` を選択していること
- `balena` CLI を利用できること

手順:
1. `cp .env.template .env` で雛形を作成し、パスワード類を変更します。
2. balenaCloud の fleet または device の環境変数にも、少なくとも `DB_PASSWORD`、`DB_ROOT_PASSWORD`、`GRAFANA_ADMIN_PASSWORD` を登録します。Cloudflare Tunnel を使う場合は `CF_TUNNEL_TOKEN` も登録します。
   USB 補助サービスを使う場合は `USB_LABEL=PI4DATA` を確認します。
3. `balena login` または `balena login --token <API_TOKEN>` でログインします。
4. `balena push Pi-Smarthome --source .` を実行してデプロイします。

balenaCloud 側の環境変数を優先したい場合は、機密値を `.env` にコミットしないでください。`.gitignore` では `.env` を除外しています。

補足:
- Zabbix の公式コンテナはコンポーネントごとに分かれており、この構成もそれに合わせています。
- Zabbix 6 以降では MariaDB/MySQL の関数作成まわりで `log_bin_trust_function_creators=1` が必要になる場合があるため、MariaDB 起動オプションに設定済みです。これは Zabbix のコンテナ手順に基づく対応です。

## GitHub Actions による自動デプロイ
このリポジトリには `main` ブランチ更新時と手動実行時に `balena push` を行うワークフローを含めています。

GitHub Secrets:
- `BALENA_API_TOKEN`: balenaCloud の API token
- `BALENA_FLEET`: デプロイ先 fleet 名。今回は `Pi-Smarthome`

設定手順:
1. GitHub リポジトリの `Settings > Secrets and variables > Actions` を開きます。
2. 上記 2 つの Secrets を登録します。
3. `main` ブランチへ push すると `.github/workflows/balena-deploy.yml` が実行されます。

注意:
- balenaCloud 側の fleet 環境変数も事前に設定してください。
- `balena push` は fleet 全体のリリースを更新するため、本番運用前にステージング fleet で確認するのが安全です。

## 使い方と運用メモ
- 初回起動後、Zabbix Web は `http://<device-ip>:8080`、Grafana は `http://<device-ip>:3000` で確認できます。
- Zabbix Server は TCP `10051` を待ち受けるため、Pi 3 側の `zabbix_sender` や連携設定をこのアドレスへ向けてください。
- 永続化は Docker volume を利用しています。SD 消耗を避けるため、MariaDB と Grafana の実データは USB ストレージ側へ逃がす前提で運用してください。
- USB ストレージ運用の前提と注意点は [`docs/usb-storage.md`](/Users/serken/Desktop/4b/docs/usb-storage.md) を参照してください。
- 実機確認の流れは [`docs/balena-usb-setup.md`](/Users/serken/Desktop/4b/docs/balena-usb-setup.md) にまとめています。
- 構成変更時は `AGENTS.md` とこの `README.md` を必ず更新してください。

## Raspberry Pi 3 側との接続
`/Users/serken/Desktop/3` の Pi 3 リポジトリを確認したところ、Pi 3 側は `zabbix_agentd` でスマートメーター値を公開する構成です。Pi 4 側とは次の前提で接続します。

- Pi 3 側の `ZABBIX_SERVER` には、Pi 4 上の Zabbix Server の LAN IP またはローカルホスト名を設定する
- Cloudflare Tunnel の hostname である `zab.serken.tech` は Web UI 用であり、Agent / Server 間通信用の宛先には使わない
- Pi 3 側のホスト名は既定で `pi-wi-sun`
- Pi 3 側では `smartmeter.power`、`smartmeter.current.r`、`smartmeter.current.t` などの item key を Zabbix Agent から取得できる

運用上の推奨:
- Pi 4 の LAN 側 IP を固定する
- Pi 3 から Pi 4 への疎通確認を先に行う
- Zabbix 上では Pi 3 用ホストを `pi-wi-sun` で作成し、Pi 3 リポジトリに含まれるテンプレートを import して使う

## USB ストレージ方針
この構成では、DB データや可視化データの保存先を SD ではなく USB ストレージへ寄せるのが前提です。

重要な点:
- balena のマルチコンテナでは `docker-compose.yml` の bind mount に制約があり、任意のホスト USB パスを単純に指定する設計は避けるべきです。
- そのため、アプリ側 Compose だけで完結させず、balenaOS 側の永続データ運用として USB を使う方針にしています。
- USB ストレージは `ext4`、常設接続、UUID または LABEL 管理を推奨します。
- このリポジトリには `usb-storage` 補助サービスを追加してあり、`PI4DATA` ラベルの USB を自動 mount できます。
- ただし、この補助サービスだけでは `mariadb-data` や `grafana-data` の live volume の実体は USB に移りません。
- SD カード消耗を本当に減らしたい場合、本命は `/var/lib/docker` を含む Docker 永続データ領域を USB 側で運用することです。
- つまり、`usb-storage` は確認・補助・バックアップ用途であり、SD 消耗対策そのものを単独で解決するものではありません。

確認コマンド例:
- `lsblk -f`

この部分は Host 側運用を伴うため、実機でのストレージ認識と再起動後の継続性を必ず確認してください。

`usb-storage` サービスの役割:
- `LABEL=PI4DATA` の USB を検出する
- コンテナ内 `/mnt/usb` に自動 mount する
- 将来のバックアップ保存先や移行作業用の補助領域として使う

本当にやるべきこと:
- MariaDB や Grafana の live data を SD に書かせない
- そのために Host 側の Docker 永続データ設計を USB 前提にする
- この部分はアプリ Compose ではなく balenaOS 実機運用として扱う

## Cloudflare Tunnel
Cloudflare の公式手順では、リモート管理トンネルは token だけで実行できます。Docker 実行例も `cloudflare/cloudflared:latest tunnel --no-autoupdate run --token <TUNNEL_TOKEN>` です。このリポジトリでは同じ方式を `cloudflared` サービスに組み込んでいます。

設定手順:
1. Cloudflare Zero Trust で tunnel を作成します。
2. `Networks > Tunnels` から対象 tunnel を開き、Docker 用のインストールコマンドから token 部分を取得します。
3. balenaCloud の environment variables に `CF_TUNNEL_TOKEN` を登録します。
4. Cloudflare 側で public hostname を設定し、`http://zabbix-web:8080` または `http://grafana:3000` にルーティングします。

推奨 hostname 設定例:
- `graf.serken.tech` -> `http://grafana:3000`
- `zab.serken.tech` -> `http://zabbix-web:8080`

注意:
- `cloudflared` は token 未設定時でも待機するため、他サービスの起動は阻害しません。
- Zabbix Server の `10051/tcp` を Cloudflare Tunnel でそのまま使う場合は、HTTP 公開ではなく TCP/Access 構成が別途必要です。現時点では Web UI 公開用途を主対象にしています。
- token は強い権限を持つため、Git に含めず balenaCloud または GitHub Secrets で管理してください。
