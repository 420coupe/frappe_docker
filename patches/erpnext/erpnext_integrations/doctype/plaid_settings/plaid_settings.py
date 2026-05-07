# Copyright (c) 2018, Frappe Technologies Pvt. Ltd. and contributors
# For license information, please see license.txt

import json

import frappe
from frappe import _
from frappe.desk.doctype.tag.tag import add_tag
from frappe.model.document import Document
from frappe.utils import add_months, formatdate, getdate, sbool, today
from plaid.errors import ItemError

from erpnext.erpnext_integrations.doctype.plaid_settings.plaid_connector import PlaidConnector


class PlaidSettings(Document):
	# begin: auto-generated types
	# This code is auto-generated. Do not modify anything in this block.

	from typing import TYPE_CHECKING

	if TYPE_CHECKING:
		from frappe.types import DF

		automatic_sync: DF.Check
		enable_european_access: DF.Check
		enabled: DF.Check
		plaid_client_id: DF.Data | None
		plaid_env: DF.Literal["sandbox", "development", "production"]
		plaid_secret: DF.Password | None

	# end: auto-generated types

	@staticmethod
	@frappe.whitelist()
	def get_link_token():
		plaid = PlaidConnector()
		return plaid.get_link_token()


@frappe.whitelist()
def get_plaid_configuration():
	if frappe.db.get_single_value("Plaid Settings", "enabled"):
		plaid_settings = frappe.get_single("Plaid Settings")
		return {
			"plaid_env": plaid_settings.plaid_env,
			"link_token": plaid_settings.get_link_token(),
			"client_name": frappe.local.site,
		}

	return "disabled"


@frappe.whitelist()
def add_institution(token, response):
	response = json.loads(response)

	plaid = PlaidConnector()
	access_token, item_id = plaid.get_access_token(token)
	bank = None

	if not frappe.db.exists("Bank", response["institution"]["name"]):
		try:
			bank = frappe.get_doc(
				{
					"doctype": "Bank",
					"bank_name": response["institution"]["name"],
				}
			)
			bank.insert()
		except Exception:
			frappe.log_error("Plaid Link Error")
	else:
		bank = frappe.get_doc("Bank", response["institution"]["name"])
		bank.save()

	# Create or update Plaid Item keyed by Plaid's item_id (not institution name).
	# This allows multiple logins to the same institution without overwriting each other.
	if frappe.db.exists("Plaid Item", item_id):
		plaid_item = frappe.get_doc("Plaid Item", item_id)
		plaid_item.access_token = access_token
		plaid_item.institution_name = response["institution"]["name"]
		plaid_item.bank = bank.name
		plaid_item.save()
	else:
		plaid_item = frappe.get_doc(
			{
				"doctype": "Plaid Item",
				"item_id": item_id,
				"institution_name": response["institution"]["name"],
				"bank": bank.name,
				"access_token": access_token,
			}
		)
		plaid_item.insert()

	return {"bank": bank.as_dict(), "plaid_item": plaid_item.name}


@frappe.whitelist()
def add_bank_accounts(response, bank, company, plaid_item=None):
	try:
		response = json.loads(response)
	except TypeError:
		pass

	if isinstance(bank, str):
		bank = json.loads(bank)
	result = []

	parent_gl_account = frappe.db.get_all(
		"Account", {"company": company, "account_type": "Bank", "is_group": 1, "disabled": 0}
	)
	if not parent_gl_account:
		frappe.throw(
			_(
				"Please setup and enable a group account with the Account Type - {0} for the company {1}"
			).format(frappe.bold(_("Bank")), company)
		)

	for account in response["accounts"]:
		acc_type = frappe.db.get_value("Bank Account Type", account["type"])
		if not acc_type:
			add_account_type(account["type"])

		acc_subtype = frappe.db.get_value("Bank Account Subtype", account["subtype"])
		if not acc_subtype:
			add_account_subtype(account["subtype"])

		bank_account_name = "{} - {}".format(account["name"], bank["bank_name"])
		existing_bank_account = frappe.db.exists("Bank Account", bank_account_name)

		if not existing_bank_account:
			try:
				gl_account = frappe.get_doc(
					{
						"doctype": "Account",
						"account_name": account["name"] + " - " + response["institution"]["name"],
						"parent_account": parent_gl_account[0].name,
						"account_type": "Bank",
						"company": company,
					}
				)
				gl_account.insert(ignore_if_duplicate=True)

				new_account = frappe.get_doc(
					{
						"doctype": "Bank Account",
						"bank": bank["bank_name"],
						"account": gl_account.name,
						"account_name": account["name"],
						"account_type": account.get("type", ""),
						"account_subtype": account.get("subtype", ""),
						"mask": account.get("mask", ""),
						"integration_id": account["id"],
						"is_company_account": 1,
						"company": company,
						"plaid_item": plaid_item,
					}
				)
				new_account.insert()

				result.append(new_account.name)
			except frappe.UniqueValidationError:
				frappe.msgprint(
					_("Bank account {0} already exists and could not be created again").format(
						account["name"]
					)
				)
			except Exception:
				frappe.log_error("Plaid Link Error")
				frappe.throw(
					_("There was an error creating Bank Account while linking with Plaid."),
					title=_("Plaid Link Failed"),
				)

		else:
			try:
				existing_account = frappe.get_doc("Bank Account", existing_bank_account)
				update_data = {
					"bank": bank["bank_name"],
					"account_name": account["name"],
					"account_type": account.get("type", ""),
					"account_subtype": account.get("subtype", ""),
					"mask": account.get("mask", ""),
					"integration_id": account["id"],
				}
				if plaid_item:
					update_data["plaid_item"] = plaid_item
				existing_account.update(update_data)
				existing_account.save()
				result.append(existing_bank_account)
			except Exception:
				frappe.log_error("Plaid Link Error")
				frappe.throw(
					_("There was an error updating Bank Account {} while linking with Plaid.").format(
						existing_bank_account
					),
					title=_("Plaid Link Failed"),
				)

	return result


def add_account_type(account_type):
	try:
		frappe.get_doc({"doctype": "Bank Account Type", "account_type": account_type}).insert()
	except Exception:
		frappe.throw(frappe.get_traceback())


def add_account_subtype(account_subtype):
	try:
		frappe.get_doc({"doctype": "Bank Account Subtype", "account_subtype": account_subtype}).insert()
	except Exception:
		frappe.throw(frappe.get_traceback())


def sync_transactions(bank, bank_account):
	"""Sync transactions based on the last integration date as the start date, after sync is completed
	add the transaction date of the oldest transaction as the last integration date."""
	last_transaction_date = frappe.db.get_value("Bank Account", bank_account, "last_integration_date")
	if last_transaction_date:
		start_date = formatdate(last_transaction_date, "YYYY-MM-dd")
	else:
		start_date = formatdate(add_months(today(), -12), "YYYY-MM-dd")
	end_date = formatdate(today(), "YYYY-MM-dd")

	try:
		transactions = get_transactions(
			bank=bank, bank_account=bank_account, start_date=start_date, end_date=end_date
		)

		result = []
		if transactions:
			for transaction in reversed(transactions):
				result += new_bank_transaction(transaction)

		if result:
			last_transaction_date = frappe.db.get_value("Bank Transaction", result.pop(), "date")

			frappe.logger().info(
				f"Plaid added {len(result)} new Bank Transactions from '{bank_account}' between {start_date} and {end_date}"
			)

			frappe.db.set_value("Bank Account", bank_account, "last_integration_date", last_transaction_date)
	except Exception:
		frappe.log_error(frappe.get_traceback(), _("Plaid transactions sync error"))


def get_transactions(bank, bank_account=None, start_date=None, end_date=None):
	access_token = None

	if bank_account:
		related_bank = frappe.db.get_values(
			"Bank Account", bank_account, ["bank", "integration_id", "plaid_item"], as_dict=True
		)
		plaid_item_name = related_bank[0].plaid_item if related_bank else None
		account_id = related_bank[0].integration_id if related_bank else None

		if plaid_item_name:
			access_token = frappe.get_doc("Plaid Item", plaid_item_name).get_password("access_token")
		else:
			# Backward compat: fall back to Bank.plaid_access_token and lazily migrate
			access_token = frappe.db.get_value("Bank", related_bank[0].bank, "plaid_access_token")
			if access_token and related_bank:
				_lazy_migrate_plaid_item(bank_account, related_bank[0].bank, access_token)
	else:
		access_token = frappe.db.get_value("Bank", bank, "plaid_access_token")
		account_id = None

	plaid = PlaidConnector(access_token)

	transactions = []
	try:
		transactions = plaid.get_transactions(start_date=start_date, end_date=end_date, account_id=account_id)
	except ItemError as e:
		if e.code == "ITEM_LOGIN_REQUIRED":
			msg = _("There was an error syncing transactions.") + " "
			msg += _("Please refresh or reset the Plaid linking of the Bank {}.").format(bank) + " "
			frappe.log_error(message=msg, title=_("Plaid Link Refresh Required"))

	return transactions


def _lazy_migrate_plaid_item(bank_account, bank_name, access_token):
	"""Lazily create a Plaid Item for Bank Accounts that predate the Plaid Item doctype.
	On the first sync of a legacy account, this creates a synthetic Plaid Item using the
	Bank.plaid_access_token and links it to the Bank Account."""
	try:
		# If a Plaid Item already exists for this bank, reuse it
		existing = frappe.db.get_value("Plaid Item", {"bank": bank_name}, "name")
		if existing:
			frappe.db.set_value("Bank Account", bank_account, "plaid_item", existing)
			return

		# Create a synthetic Plaid Item (item_id is unknown for legacy tokens)
		synthetic_item_id = "migrated-{}".format(frappe.generate_hash(bank_name, length=16))
		plaid_item = frappe.get_doc(
			{
				"doctype": "Plaid Item",
				"item_id": synthetic_item_id,
				"institution_name": bank_name,
				"bank": bank_name,
				"access_token": access_token,
			}
		)
		plaid_item.insert(ignore_permissions=True)
		frappe.db.set_value("Bank Account", bank_account, "plaid_item", plaid_item.name)
	except Exception:
		frappe.log_error("Plaid lazy migration error")


def new_bank_transaction(transaction):
	result = []

	bank_account = frappe.db.get_value(
		"Bank Account", dict(integration_id=transaction["account_id"])
	)

	amount = float(transaction["amount"])
	if amount >= 0.0:
		deposit = 0.0
		withdrawal = amount
	else:
		deposit = abs(amount)
		withdrawal = 0.0

	tags = []
	if transaction["category"]:
		try:
			tags += transaction["category"]
			tags += [f'Plaid Cat. {transaction["category_id"]}']
		except KeyError:
			pass

	if not frappe.db.exists(
		"Bank Transaction", dict(transaction_id=transaction["transaction_id"])
	) and not sbool(transaction["pending"]):
		try:
			new_transaction = frappe.get_doc(
				{
					"doctype": "Bank Transaction",
					"date": getdate(transaction["date"]),
					"bank_account": bank_account,
					"deposit": deposit,
					"withdrawal": withdrawal,
					"currency": transaction["iso_currency_code"],
					"transaction_id": transaction["transaction_id"],
					"transaction_type": (
						transaction["transaction_code"] or transaction["payment_meta"]["payment_method"]
					),
					"reference_number": (
						transaction["check_number"]
						or transaction["payment_meta"]["reference_number"]
						or transaction["name"]
					),
					"description": transaction["name"],
				}
			)
			new_transaction.insert()
			new_transaction.submit()

			for tag in tags:
				add_tag(tag, "Bank Transaction", new_transaction.name)

			result.append(new_transaction.name)

		except Exception:
			frappe.throw(_("Bank transaction creation error"))

	return result


def automatic_synchronization():
	settings = frappe.get_doc("Plaid Settings", "Plaid Settings")
	if settings.enabled == 1 and settings.automatic_sync == 1:
		enqueue_synchronization()


@frappe.whitelist()
def enqueue_synchronization():
	plaid_accounts = frappe.get_all(
		"Bank Account", filters={"integration_id": ["!=", ""]}, fields=["name", "bank"]
	)

	for plaid_account in plaid_accounts:
		frappe.enqueue(
			"erpnext.erpnext_integrations.doctype.plaid_settings.plaid_settings.sync_transactions",
			bank=plaid_account.bank,
			bank_account=plaid_account.name,
		)


@frappe.whitelist()
def get_link_token_for_update(access_token=None, plaid_item=None):
	if plaid_item:
		access_token = frappe.get_doc("Plaid Item", plaid_item).get_password("access_token")
	plaid = PlaidConnector(access_token)
	return plaid.get_link_token(update_mode=True)


def get_company(bank_account_name):
	from frappe.defaults import get_user_default

	company_names = frappe.db.get_all("Company", pluck="name")
	if len(company_names) == 1:
		return company_names[0]
	if frappe.db.exists("Bank Account", bank_account_name):
		return frappe.db.get_value("Bank Account", bank_account_name, "company")
	company_default = get_user_default("Company")
	if company_default:
		return company_default
	frappe.throw(_("Could not detect the Company for updating Bank Accounts"))


@frappe.whitelist()
def update_bank_account_ids(response, plaid_item=None):
	data = json.loads(response)
	institution_name = data["institution"]["name"]
	bank = frappe.get_doc("Bank", institution_name).as_dict()
	bank_account_name = f"{data['account']['name']} - {institution_name}"
	return add_bank_accounts(response, bank, get_company(bank_account_name), plaid_item=plaid_item)
