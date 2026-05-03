// Copyright (c) 2018, Frappe Technologies Pvt. Ltd. and contributors
// For license information, please see license.txt
frappe.provide("erpnext.integrations");

frappe.ui.form.on("Bank", {
  refresh: function (frm) {
    add_fields_to_mapping_table(frm);
    frm.toggle_display(["address_html", "contact_html"], !frm.doc.__islocal);

    if (frm.doc.__islocal) {
      frm.set_df_property("address_and_contact", "hidden", 1);
      frappe.contacts.clear_address_and_contact(frm);
    } else {
      frm.set_df_property("address_and_contact", "hidden", 0);
      frappe.contacts.render_address_and_contact(frm);
    }

    // Show one "Refresh Plaid Link" button per Plaid Item linked to this bank.
    // This correctly handles multiple logins to the same institution.
    if (!frm.doc.__islocal) {
      frappe.db
        .get_list("Plaid Item", {
          filters: { bank: frm.doc.name },
          fields: ["name", "institution_name"],
        })
        .then((items) => {
          items.forEach((item) => {
            const label = item.institution_name
              ? __("Refresh Plaid Link — {0}", [item.institution_name])
              : __("Refresh Plaid Link");
            frm.add_custom_button(label, () => {
              new erpnext.integrations.refreshPlaidLink(item.name);
            });
          });

          // Legacy fallback: bank has plaid_access_token but no Plaid Item records yet
          if (items.length === 0 && frm.doc.plaid_access_token) {
            frm.add_custom_button(__("Refresh Plaid Link"), () => {
              new erpnext.integrations.refreshPlaidLink(
                null,
                frm.doc.plaid_access_token,
              );
            });
          }
        });
    }
  },
});

let add_fields_to_mapping_table = function (frm) {
  let options = [];

  frappe.model.with_doctype("Bank Transaction", function () {
    let meta = frappe.get_meta("Bank Transaction");
    meta.fields.forEach((value) => {
      if (!["Section Break", "Column Break"].includes(value.fieldtype)) {
        options.push(value.fieldname);
      }
    });
  });

  const grid = frm.fields_dict.bank_transaction_mapping?.grid;

  if (grid) {
    grid.update_docfield_property("bank_transaction_field", "options", options);
  }
};

erpnext.integrations.refreshPlaidLink = class refreshPlaidLink {
  /**
   * @param {string|null} plaid_item  - Name of the Plaid Item document (preferred)
   * @param {string|null} access_token_fallback - Raw access token (legacy fallback only)
   */
  constructor(plaid_item, access_token_fallback) {
    this.plaid_item = plaid_item;
    this.access_token_fallback = access_token_fallback || null;
    this.plaidUrl = "https://cdn.plaid.com/link/v2/stable/link-initialize.js";
    this.init_config();
  }

  async init_config() {
    this.plaid_env = await frappe.db.get_single_value(
      "Plaid Settings",
      "plaid_env",
    );
    this.token = await this.get_link_token_for_update();
    this.init_plaid();
  }

  async get_link_token_for_update() {
    const params = this.plaid_item
      ? { plaid_item: this.plaid_item }
      : { access_token: this.access_token_fallback };

    const token = await frappe.xcall(
      "erpnext.erpnext_integrations.doctype.plaid_settings.plaid_settings.get_link_token_for_update",
      params,
    );
    if (!token) {
      frappe.throw(
        __(
          "Cannot retrieve link token for update. Check Error Log for more information",
        ),
      );
    }
    return token;
  }

  init_plaid() {
    const me = this;
    me.loadScript(me.plaidUrl)
      .then(() => {
        me.onScriptLoaded(me);
      })
      .then(() => {
        if (me.linkHandler) {
          me.linkHandler.open();
        }
      })
      .catch((error) => {
        me.onScriptError(error);
      });
  }

  loadScript(src) {
    return new Promise(function (resolve, reject) {
      if (document.querySelector("script[src='" + src + "']")) {
        resolve();
        return;
      }
      const el = document.createElement("script");
      el.type = "text/javascript";
      el.async = true;
      el.src = src;
      el.addEventListener("load", resolve);
      el.addEventListener("error", reject);
      el.addEventListener("abort", reject);
      document.head.appendChild(el);
    });
  }

  onScriptLoaded(me) {
    me.linkHandler = Plaid.create({
      // eslint-disable-line no-undef
      env: me.plaid_env,
      token: me.token,
      onSuccess: (token, response) => me.plaid_success(token, response),
    });
  }

  onScriptError(error) {
    frappe.msgprint(
      __(
        "There was an issue connecting to Plaid's authentication server. Check browser console for more information",
      ),
    );
    console.error(error);
  }

  plaid_success(token, response) {
    frappe
      .xcall(
        "erpnext.erpnext_integrations.doctype.plaid_settings.plaid_settings.update_bank_account_ids",
        {
          response: response,
          plaid_item: this.plaid_item,
        },
      )
      .then(() => {
        frappe.show_alert({
          message: __("Plaid Link Updated"),
          indicator: "green",
        });
      });
  }
};
