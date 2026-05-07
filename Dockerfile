ARG ERPNEXT_VERSION=v16.17.0
FROM frappe/erpnext:${ERPNEXT_VERSION}

# Supabase/PostgreSQL session pooler compatibility patches.
# Baked into the image at build time to avoid file bind mount fragility.
#
# setup_db.py:            fixes cur_db_name, ALTER DATABASE OWNER TO, psql bootstrap creds
# goal.py:                fixes AmbiguousFunction sum(unknown) on PG dashboard widgets
# financial_statements.py: guards FORCE INDEX (MySQL-only) from PostgreSQL
# pricing_rule/utils.py:  IFNULL → COALESCE (ANSI SQL)
# pos_register.py:        IF()/IFNULL → CASE WHEN/COALESCE (ANSI SQL)
# number_card.py:         order_by=None on aggregate get_list (PostgreSQL GroupingError)
#
# When upgrading ERPNEXT_VERSION, re-copy base files from the new image,
# re-apply patches, then rebuild:
#   docker run --rm --entrypoint="" frappe/erpnext:<newver> \
#     cat /home/frappe/frappe-bench/apps/frappe/frappe/database/postgres/setup_db.py \
#     > patches/frappe/database/postgres/setup_db.py
#   docker run --rm --entrypoint="" frappe/erpnext:<newver> \
#     cat /home/frappe/frappe-bench/apps/frappe/frappe/utils/goal.py \
#     > patches/frappe/utils/goal.py
#   docker run --rm --entrypoint="" frappe/erpnext:<newver> \
#     cat /home/frappe/frappe-bench/apps/erpnext/erpnext/accounts/report/financial_statements.py \
#     > patches/erpnext/accounts/report/financial_statements.py
#   docker run --rm --entrypoint="" frappe/erpnext:<newver> \
#     cat /home/frappe/frappe-bench/apps/erpnext/erpnext/accounts/doctype/pricing_rule/utils.py \
#     > patches/erpnext/accounts/doctype/pricing_rule/utils.py
#   docker run --rm --entrypoint="" frappe/erpnext:<newver> \
#     cat /home/frappe/frappe-bench/apps/erpnext/erpnext/accounts/report/pos_register/pos_register.py \
#     > patches/erpnext/accounts/report/pos_register/pos_register.py
#   docker run --rm --entrypoint="" frappe/erpnext:<newver> \
#     cat /home/frappe/frappe-bench/apps/frappe/frappe/desk/doctype/number_card/number_card.py \
#     > patches/frappe/desk/doctype/number_card/number_card.py

COPY --chown=frappe:frappe \
     patches/frappe/database/postgres/setup_db.py \
     /home/frappe/frappe-bench/apps/frappe/frappe/database/postgres/setup_db.py

COPY --chown=frappe:frappe \
     patches/frappe/utils/goal.py \
     /home/frappe/frappe-bench/apps/frappe/frappe/utils/goal.py

# Plaid Item doctype: enables per-login-session token storage, fixing
# INVALID_ACCOUNT_ID errors caused by multiple logins to the same institution.
COPY --chown=frappe:frappe \
     patches/erpnext/erpnext_integrations/doctype/plaid_item/ \
     /home/frappe/frappe-bench/apps/erpnext/erpnext/erpnext_integrations/doctype/plaid_item/

COPY --chown=frappe:frappe \
     patches/erpnext/erpnext_integrations/doctype/plaid_settings/plaid_connector.py \
     /home/frappe/frappe-bench/apps/erpnext/erpnext/erpnext_integrations/doctype/plaid_settings/plaid_connector.py

COPY --chown=frappe:frappe \
     patches/erpnext/erpnext_integrations/doctype/plaid_settings/plaid_settings.py \
     /home/frappe/frappe-bench/apps/erpnext/erpnext/erpnext_integrations/doctype/plaid_settings/plaid_settings.py

COPY --chown=frappe:frappe \
     patches/erpnext/erpnext_integrations/doctype/plaid_settings/plaid_settings.js \
     /home/frappe/frappe-bench/apps/erpnext/erpnext/erpnext_integrations/doctype/plaid_settings/plaid_settings.js

COPY --chown=frappe:frappe \
     patches/erpnext/accounts/doctype/bank_account/bank_account.json \
     /home/frappe/frappe-bench/apps/erpnext/erpnext/accounts/doctype/bank_account/bank_account.json

COPY --chown=frappe:frappe \
     patches/erpnext/accounts/doctype/bank/bank.js \
     /home/frappe/frappe-bench/apps/erpnext/erpnext/accounts/doctype/bank/bank.js

# financial_statements.py: guards FORCE INDEX (MySQL-only) from PostgreSQL
COPY --chown=frappe:frappe \
     patches/erpnext/accounts/report/financial_statements.py \
     /home/frappe/frappe-bench/apps/erpnext/erpnext/accounts/report/financial_statements.py

# pricing_rule/utils.py: IFNULL → COALESCE (ANSI SQL, portable)
COPY --chown=frappe:frappe \
     patches/erpnext/accounts/doctype/pricing_rule/utils.py \
     /home/frappe/frappe-bench/apps/erpnext/erpnext/accounts/doctype/pricing_rule/utils.py

# pos_register.py: IF()/IFNULL → CASE WHEN/COALESCE (ANSI SQL, portable)
COPY --chown=frappe:frappe \
     patches/erpnext/accounts/report/pos_register/pos_register.py \
     /home/frappe/frappe-bench/apps/erpnext/erpnext/accounts/report/pos_register/pos_register.py

# number_card.py: order_by=None on aggregate get_list fixes PostgreSQL GroupingError
COPY --chown=frappe:frappe \
     patches/frappe/desk/doctype/number_card/number_card.py \
     /home/frappe/frappe-bench/apps/frappe/frappe/desk/doctype/number_card/number_card.py
