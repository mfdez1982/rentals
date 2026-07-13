class CreateAgreementTenants < ActiveRecord::Migration[8.1]
  def change
    create_table :agreement_tenants do |t|
      t.references :rental_agreement, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.string :invited_email, null: false
      t.string :invitation_token, null: false
      t.integer :status, null: false, default: 0
      t.datetime :invited_at, null: false
      t.datetime :responded_at
      t.datetime :landlord_acknowledged_at
      t.datetime :tenant_acknowledged_at

      t.timestamps
    end

    add_index :agreement_tenants, :invitation_token, unique: true
    add_index :agreement_tenants, [ :rental_agreement_id, :invited_email ],
      unique: true,
      where: "status IN (0,1)",
      name: "index_agreement_tenants_live_unique"
  end
end
