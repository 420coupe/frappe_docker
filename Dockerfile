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

# Apply all frappe patches in a single layer (patches/frappe/ mirrors .../apps/frappe/frappe/)
COPY --chown=frappe:frappe patches/frappe/ /home/frappe/frappe-bench/apps/frappe/frappe/

# Apply all erpnext patches in a single layer (patches/erpnext/ mirrors .../apps/erpnext/erpnext/)
COPY --chown=frappe:frappe patches/erpnext/ /home/frappe/frappe-bench/apps/erpnext/erpnext/
