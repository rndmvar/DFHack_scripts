# Tell caravans that you're done trading, and they need to get out
=begin

done_trading

=end

df.ui.caravans.each do |caravan|
    # set the time left on the caravan to 10 ticks
    caravan.time_remaining = 10 if caravan.time_remaining > 10
end
