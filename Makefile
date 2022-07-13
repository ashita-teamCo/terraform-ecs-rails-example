dir = staging/main
ws = default
use_vault = no
workspace = $(ws)

include $(shell dirname $(dir))/params.make

LRED = '\033[1;31m'   # Light Red
LCYAN = '\033[1;36m'  # Light Cyan
NC = '\033[0m'        # No Color

# ヘルプを表示 (default target)
usage:
	@echo "Usage:"
	@echo "  make [dir=working_directory] [ws=workspace_name] target"
	@echo ""
	@echo "  - target: (init | validate | plan | apply | output)"
	@echo "  - working_directory: staging/main, demo/main, production/main ..."
	@echo "  - workspace_name: (default | test)"
	@echo ""
	@echo "Examples:"
	@echo ""
	@echo "  # staging 環境で \`terraform plan\` を実行する (dir のデフォルトは staging/main)"
	@echo "  make plan"
	@echo ""
	@echo "  # demo 環境で \`terraform plan\` を実行する"
	@echo "  make dir=demo/main plan"
	@echo ""
	@echo "  # workspace として \`test\` を選択し staging 環境で \`terraform plan\` を実行する"
	@echo "  make workspace=test plan"
	@echo "  make ws=test plan           # workspace は ws と省略可能"
	@echo ""
	@echo "  # 特定のリソースだけ plan する (一部コマンドは opt='xxx' の形式でオプションを渡すことができる)"
	@echo "  make plan opts='-target=module.main.module.alb[\"sre\"].aws_lb.this'"
	@echo ""

init_all:
	@for env in staging demo production; do \
		for segment in acm main maintenance healthchecksio; do \
			${MAKE} init dir=$$env/$$segment; \
		done \
	done
	@for env in staging production; do \
		for segment in account shared; do \
			${MAKE} init dir=$$env/$$segment; \
		done \
	done

init:
	$(call terraform,$(dir),init,$(opts))

# dir ディレクトリ配下で `terraform` コマンドを実行するマクロ
#   MFA 認証が必要な環境の場合は aws-vault 経由で terraform コマンドを実行する
#   それ以外はそのまま terraform コマンドを実行する
define terraform
	@if echo "$(use_vault)" | grep -q -e yes; then \
		echo $(LCYAN)=\> aws-vault exec $(profile) -- terraform -chdir=$1 $2 $3 $4$(NC);\
		aws-vault exec $(profile) -- terraform -chdir=$1 $2 $3 $4;\
	else \
		echo $(LCYAN)=\> terraform -chdir=$1 $2 $3 $4$(NC);\
		terraform -chdir=$1 $2 $3 $4;\
	fi
endef

validate:
	$(call terraform,$(dir),validate)

.workspace_select:
	$(call terraform,$(dir),workspace,select,$(workspace))

plan: validate .workspace_select
	$(call terraform,$(dir),plan,$(opts))

apply: validate .workspace_select
	@if echo "$(dir)" | grep -q -e production -e demo; then \
		echo $(LRED); \
		echo '###############################################################################'; \
		echo $(NC)\'$(dir)\'$(LRED) での terraform apply は細心の注意を払って実行してください; \
		echo '###############################################################################'; \
		echo $(NC); \
		echo "続行するには ENTER を押してください (中断は Ctrl + C)"; \
		read; \
	fi
	$(call terraform,$(dir),apply,$(opts))

output: validate .workspace_select
	$(call terraform,$(dir),output,$(opts))

refresh: validate .workspace_select
	$(call terraform,$(dir),apply,-refresh-only,$(opts))

state_list: .workspace_select
	$(call terraform,$(dir),state,list)
