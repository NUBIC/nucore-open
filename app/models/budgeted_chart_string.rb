class BudgetedChartString < ActiveRecord::Base
  include NUCore::Database::DateHelper

  validates_presence_of :fund, :dept, :starts_at, :expires_at
  validates_length_of   :fund, :is => 3
  validates_length_of   :dept, :is => 7
  validates_length_of   :project, :is => 8, :allow_blank => true
  validates_length_of   :activity, :is => 2, :allow_blank => true
  validates_length_of   :account, :is => 5, :allow_blank => true

  def self.import(filename)
    file = File.open(filename, 'r') rescue nil
    if file.blank?
      puts "error: Invalid file #{filename}"
      return
    end

    deleted   = self.count
    imported  = 0
    skipped   = 0
    invalid   = 0

    self.transaction do
      # delete all records
      self.delete_all

      # import records
      begin
        # add testing/place holder records
        BudgetedChartString.create(:fund => '123', :dept => '1234567', :project => '12345678', :account => '75340',
                                   :starts_at => Time.zone.now-1.week, :expires_at => Time.zone.now+1.year)
        BudgetedChartString.create(:fund => '123', :dept => '1234567', :project => '12345678', :account => '50617',
                                   :starts_at => Time.zone.now-1.week, :expires_at => Time.zone.now+1.year)
        BudgetedChartString.create(:fund => '111', :dept => '2222222', :project => '33333333', :account => '75340',
                                   :starts_at => Time.zone.now-1.week, :expires_at => Time.zone.now+1.year)
        BudgetedChartString.create(:fund => '111', :dept => '2222222', :project => '33333333', :account => '50617',
                                   :starts_at => Time.zone.now-1.week, :expires_at => Time.zone.now+1.year)
        while line = file.readline.strip
          # parse, import line
          case
          when line.match(/^\d{4,4}\|/)
            # chart string with fiscal year
            tokens = line.split('|').map{ |s| s.gsub('-', '') }
            # build start_at, expires_at from fiscal year
            fiscal_year = tokens[0]
            starts_at   = SettingsHelper::fiscal_year(fiscal_year.to_i) #Time.zone.parse("#{fiscal_year}0901")
            expires_at  = starts_at + 1.year - 1.second
            # parse fields
            fund, dept, project, activity, account = tokens[1], tokens[2], tokens[3], tokens[4], tokens[5]
          when line.match(/\d{2,2}-[A-Z]{3,3}-\d{2,2}\|\d{2,2}-[A-Z]{3,3}-\d{2,2}$/)
            # chart string with start and expire dates
            tokens = line.split('|').map{ |s| s.gsub('-', '') }
            # parse fields
            fund, dept, project, activity, account = tokens[1], tokens[2], tokens[3], tokens[4], tokens[5]
            starts_at, expires_at = parse_2_digit_year_date(tokens[6]), parse_2_digit_year_date(tokens[7]).end_of_day
          else
            # invalid line
            puts "error: skipping - #{line}"
            skipped += 1
          end
          bcs = BudgetedChartString.create(:fund => fund, :dept => dept, :project => project, :activity => activity, :account => account,
                                           :starts_at => starts_at, :expires_at => expires_at)
          if !bcs.valid?
            puts "error: invalid account - #{line}"
            invalid += 1
          else
            imported += 1
          end
        end
      rescue EOFError
        file.close
        logger.info "notice: imported #{imported} records, skipped #{skipped} records, found #{invalid} invalid records"
      end
    end
  end
end
