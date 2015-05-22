require 'stuff-classifier'

class TClassifier
  def initialize(subject)
    @subject = subject
  end

  def categories
    StuffClassifier::Bayes.open(@subject).categories
  end

  def category_list
    StuffClassifier::Bayes.open(@subject).category_list
  end

  def subject_exists
    categories.count > 0
  end

  def number_of_classifications
    category_list.to_a.inject(0) do |memo, (_, cat)|
      memo + cat[:_count]
    end
  end

  def train(classification, text)
    StuffClassifier::Bayes.open(@subject) do |cls|
      cls.train(classification.to_sym, text)
    end
  end

  def classify(text)
    StuffClassifier::Bayes.open(@subject).classify(text)
  end
end
