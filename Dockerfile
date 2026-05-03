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
