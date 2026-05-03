# Copyright (c) 2024, Frappe Technologies Pvt. Ltd. and contributors
# For license information, please see license.txt

from frappe.model.document import Document


class PlaidItem(Document):
	# begin: auto-generated types
	# This code is auto-generated. Do not modify anything in this block.

	from typing import TYPE_CHECKING

	if TYPE_CHECKING:
		from frappe.types import DF

		access_token: DF.Password | None
		bank: DF.Link
		institution_name: DF.Data | None
		item_id: DF.Data
		last_sync: DF.Datetime | None

	# end: auto-generated types
	pass
