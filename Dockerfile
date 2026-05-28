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
# trends.py:              IF() → CASE WHEN (Sales Order/Purchase Order/Invoice Trends reports)
# payment_entry.py:       IF()/IFNULL → COALESCE(NULLIF())/COALESCE (ANSI SQL)
# sales_order_analysis.py: IF()/IFNULL/DATEDIFF → CASE WHEN/COALESCE/db_type conditional
# inactive_customers.py:  IF()/DATEDIFF/single-quoted aliases → CASE WHEN/db_type conditional
# inactive_sales_items.py: DATEDIFF → db_type conditional
# supplier_scorecard_variable.py: DATEDIFF (4 occurrences) → db_type conditional
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
#   docker run --rm --entrypoint="" frappe/erpnext:<newver> \
#     cat /home/frappe/frappe-bench/apps/erpnext/erpnext/controllers/trends.py \
#     > patches/erpnext/controllers/trends.py
#   docker run --rm --entrypoint="" frappe/erpnext:<newver> \
#     cat /home/frappe/frappe-bench/apps/erpnext/erpnext/accounts/doctype/payment_entry/payment_entry.py \
#     > patches/erpnext/accounts/doctype/payment_entry/payment_entry.py
#   docker run --rm --entrypoint="" frappe/erpnext:<newver> \
#     cat /home/frappe/frappe-bench/apps/erpnext/erpnext/selling/report/sales_order_analysis/sales_order_analysis.py \
#     > patches/erpnext/selling/report/sales_order_analysis/sales_order_analysis.py
#   docker run --rm --entrypoint="" frappe/erpnext:<newver> \
#     cat /home/frappe/frappe-bench/apps/erpnext/erpnext/selling/report/inactive_customers/inactive_customers.py \
#     > patches/erpnext/selling/report/inactive_customers/inactive_customers.py
#   docker run --rm --entrypoint="" frappe/erpnext:<newver> \
#     cat /home/frappe/frappe-bench/apps/erpnext/erpnext/accounts/report/inactive_sales_items/inactive_sales_items.py \
#     > patches/erpnext/accounts/report/inactive_sales_items/inactive_sales_items.py
#   docker run --rm --entrypoint="" frappe/erpnext:<newver> \
#     cat /home/frappe/frappe-bench/apps/erpnext/erpnext/buying/doctype/supplier_scorecard_variable/supplier_scorecard_variable.py \
#     > patches/erpnext/buying/doctype/supplier_scorecard_variable/supplier_scorecard_variable.py

# Apply all frappe patches in a single layer (patches/frappe/ mirrors .../apps/frappe/frappe/)
COPY --chown=frappe:frappe patches/frappe/ /home/frappe/frappe-bench/apps/frappe/frappe/

# Apply all erpnext patches in a single layer (patches/erpnext/ mirrors .../apps/erpnext/erpnext/)
COPY --chown=frappe:frappe patches/erpnext/ /home/frappe/frappe-bench/apps/erpnext/erpnext/
