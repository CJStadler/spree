require "state_machine_checker"
require "state_machine_checker/rspec_matchers"
require 'spec_helper'

# This is an example of using the custom matcher.
RSpec.describe "Payment state machine" do
  include StateMachineChecker
  include StateMachineChecker::CTL::API
  include StateMachineChecker::RspecMatchers

  def new_payment
    payment = Spree::Payment.new
    payment.source = create :credit_card
    payment.order = Spree::Order.create
    gateway = Spree::Gateway::Bogus.new(active: true)
    allow(gateway).to receive_messages source_required: true
    payment.payment_method = gateway
    payment.amount = 5
    payment
  end

  it "can reach completed" do
    expect { new_payment }.to satisfy(EF(:completed?))
  end

  it "can be voided directly from completed" do
    formula = AG(atom(:completed?).implies(EX(:void?)))
    expect { new_payment }.to satisfy(formula)
  end

  it "cannot fail after completed" do
    formula = AG(atom(:completed?).implies(neg(EF(:failed?))))
    expect { new_payment }.to satisfy(formula)
  end

  it "has no path from void" do
    formula = AG(atom(:void?).implies(neg(EX(->(_) { true }))))
    expect { new_payment }.to satisfy(formula)
  end

  it "may never reach a terminal state" do
    terminals = atom(:completed?)
      .or(:failed?)
      .or(:void?)
      .or(:invalid?)
    formula = EF(EG(neg(terminals)))
    expect { new_payment }.to satisfy(formula)
  end
end
