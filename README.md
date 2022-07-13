# このリポジトリについて

AWS 上に一般的な Web アプリケーションの構成を構築するための Terraform 設定を公開しています。

このリポジトリの設定をベースに、例えば以下のような構成の Web アプリケーションを構築することができます。

![](./infrastructure_overview.drawio.svg)

ただし、このリポジトリには以下は含まれていません。

- AWS アカウントに関する設定
- WAF のようにサービスを悪意ある第三者から保護するための設定
- アプリケーションのデプロイに関する設定
- アラートなどを Slack に通知するための設定
- GitHub, SendGrid, Healthchecks.io など外部サービスに関する設定

上記については必要に応じて設定が必要になります。

また、設定ファイル上 `FIXME:` とコメントされている箇所についても必要に応じて設定が必要となる場合があります。

# terraform の実行

make コマンドで実行が可能です。

## staging

```
make plan
```

Usage

```
Usage:
  make [dir=working_directory] [ws=workspace_name] target

  - target: (init | validate | plan | apply | output)
  - working_directory: staging/main, demo/main, production/main ...
  - workspace_name: (default | test)

Examples:

  # staging 環境で `terraform plan` を実行する (dir のデフォルトは staging/main)
  make plan

  # demo 環境で `terraform plan` を実行する
  make dir=demo/main plan

  # workspace として `test` を選択し staging 環境で `terraform plan` を実行する
  make workspace=test plan
  make ws=test plan           # workspace は ws と省略可能

  # 特定のリソースだけ plan する (一部コマンドは opt='xxx' の形式でオプションを渡すことができる)
  make plan opts='-target=module.main.module.alb["sre"].aws_lb.this'
```
