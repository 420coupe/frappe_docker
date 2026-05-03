ARG ERPNEXT_VERSION=v16.16.0
FROM frappe/erpnext:${ERPNEXT_VERSION}

# Supabase/PostgreSQL session pooler compatibility patches.
# Baked into the image at build time to avoid file bind mount fragility.
#
# setup_db.py: fixes cur_db_name, ALTER DATABASE OWNER TO, psql bootstrap creds
# goal.py:     fixes AmbiguousFunction sum(unknown) on PG dashboard widgets
#
# When upgrading ERPNEXT_VERSION, re-copy base files from the new image,
# re-apply patches, then rebuild:
#   docker run --rm frappe/erpnext:<newver> \
#     cat /home/frappe/frappe-bench/apps/frappe/frappe/database/postgres/setup_db.py \
#     > patches/frappe/database/postgres/setup_db.py
#   docker run --rm frappe/erpnext:<newver> \
#     cat /home/frappe/frappe-bench/apps/frappe/frappe/utils/goal.py \
#     > patches/frappe/utils/goal.py

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
