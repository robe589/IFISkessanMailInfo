#coding: utf-8
require 'bundler'
Bundler.require
require 'open-uri'
require 'pp' 
require 'date'
require 'csv'
require 'fileutils'

require './account'
require './GmailSend'

def main()
	getDateRenge=[Date.today,Date.today]#データ取得日及び表示日の範囲
	storagePath='csv/'#日付別の決算企業ファイルの保存パス
	readFileName='holdStockList.csv'
	isStdIoScreen=true
	logPath='log/log.txt'

	FileUtils.mkdir_p('csv') unless FileTest.exist?('csv')
	
	readDateToSite(getDateRenge,storagePath)
	kessanList=showHoldStock(getDateRenge,readFileName,storagePath)
	
	p kessanList
	
	str="本日の決算銘柄は\n"
	kessanList.each do |code|
		str=str+code.to_s+"\n"
	end

	gmail=GmailSend.new('ikimono.miwa589@gmail.com',$password)
	gmail.sendMail('stockInfo589@gmail.com','本日の決算銘柄',str)

end

def readDateToSite(getDateRenge,storagePath)
	Dir.glob(storagePath+"*").each do |file|
		File.delete file
	end
	saveKessanToCsv(getDateRenge,storagePath)
end

def saveKessanToCsv(getDateRenge,storagePath)
	#現在日時を取得
	startDate=getDateRenge[0]
	endDate=getDateRenge[1]
	isNextPage=false
	begin
		dateStr=startDate.strftime("%Y%m%d")
		page=1
		csv=CSV.open(storagePath+dateStr+'.csv','wb')
		begin
			isNextPage=false 
			url='http://kabuyoho.ifis.co.jp/index.php?action=tp1&sa=schedule&ym='+dateStr[0..5]+'&lst='+dateStr+'&pageID='+page.to_s
			p url
			doc=getHtmlData(url)
			
			#その日の決算銘柄をCSVに保存
			strXpath='//tr[@class="line"]';
			doc.xpath(strXpath).each_with_index do |node,i|
				strXpath='./td/a'
				data=Array.new
				node.xpath(strXpath).each_with_index do |node,i|
					data[i]=node.text
				end	
				csv<<data
			end
			page+=1
			doc.xpath('//a[@title="next page"]').each do |node|
				isNextPage=true
			end
		end while isNextPage==true
		csv.close
		startDate+=1#次の日に
	end while startDate <= endDate
end

def showHoldStock(getDateRenge,readFileName,storagePath)
	begin
		tmpHoldStockList=CSV.read(readFileName)
	rescue Errno::ENOENT
		puts readFileName+'がありません'
		return -1
	end 
	tmpHoldStockList.delete_at(0)
	holdStockList=Array.new
	tmpHoldStockList.length.times do |i|
		holdStockList[i]=Hash.new
		holdStockList[i]['code']=tmpHoldStockList[i][0].to_i
		holdStockList[i]['isNot']=true;
	end
	kessanList=searchCsv(getDateRenge,holdStockList,storagePath)
	
	return kessanList
end

def getHtmlData(url)	
	html=open(url).read
	doc=Nokogiri::HTML.parse(html,nil,'utf-8')
	#p doc.title

	return doc
end


def searchCsv(getDateRange,searchStockList,storagePath)
	startDate=getDateRange[0]
	endDate=getDateRange[1]

	kessanList=Array.new
	begin
		isDayShowItem=false
		dateStr=startDate.strftime("%Y%m%d")
		#検索"
		begin 
			csv=CSV.open(storagePath+dateStr+'.csv',"r") 
		rescue Errno::ENOENT
			return -1;
		end	
		csv.each do |row|
			searchStockList.each do |search|
				if row[0].to_i ==search['code']#見つかった
					kessanList.push(search['code'])
					search['isNot']=false
				end
			end
		end
		csv.close
		startDate+=1
	end while startDate <= endDate
	
	return kessanList
end

main()
